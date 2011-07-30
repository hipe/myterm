require 'optparse'

# an ultralight command-line parser (388 lines)
# that wraps around OptParse (can do anything it does)
# with colors
# with flexible command-like options ('officious' like -v, -h)
# with commands with arguments based off of method signatures
# with subcommands, (namespaces) arbitrarily deeply nested

module Tmx; end
module Tmx::Face; end

module Tmx::Face::Colors
  def bold str ; style str, :bright, :green end
  def hi   str ; style str, :green          end
  def ohno str ; style str, :red            end
  def yelo str ; style str, :yellow         end
  Styles = { :bright => 1, :red => 31, :yellow => 33, :green => 32, :cyan => 36 }
  Esc = "\e"  # "\u001b" ok in 1.9.2
  def style str, *styles
    nums = styles.map{ |o| o.kind_of?(Integer) ? o : Styles[o] }.compact
    "#{Esc}[#{nums.join(';')}m#{str}#{Esc}[0m"
  end
  def highlight_header str
    str.sub(/\A([^:]+:)/) { "#{hi($1)}" }
  end
end

module Tmx::Face
  class Command

    include Colors

    def initialize name, *rest, &block
      rest.any? and
        raise ArgumentError.new("too many args for command: #{rest.inspect}")
      @parser_definition = block # nil ok
      @intern = name.to_sym
    end

    class << self
      alias_method :build, :new
    end

    def build_option_parser req
      parser = build_empty_option_parser
      # we set the default value for the banner after we run the block
      # to give the client the chance to set the syntax.
      ugly, ugly_id = [parser.banner.dup, parser.banner.object_id]
      if @parser_definition
        args = [parser, req]
        @parser_definition.arity > 0 and args = args[0, @parser_definition.arity]
        instance_exec(*args, &@parser_definition)
      end
      if ugly == parser.banner && ugly_id = parser.banner.object_id
        parser.banner = usage_string
      end
      parser
    end

    def for_run parent, name_as_used
      self.parent = parent
      @out = @parent.out
      @err = @parent.err
      @name_as_used = name_as_used
      self # careful
    end

    def method
      @parent.method method_symbol
    end

    def method_symbol
      @intern.to_s.downcase.gsub(/[^a-z0-9]+/, '_').intern
    end

    def name
      @intern.to_s
    end

    def parse argv
      req = { }
      req.send(:instance_variable_set, '@method_parameters', argv)
      class << req; attr_accessor :method_parameters end
      @parent_protected_instance_methods.include?("before_parse_#{@intern}".intern) and
        ! @parent.send("before_parse_#{@intern}", req, argv) and return false
      begin
        build_option_parser(req).parse! argv
        req
      rescue OptionParser::ParseError => e
        @out.puts highlight_header(e.to_s)
        invite
        nil
      end
    end

    def summary
      build_option_parser({}).to_s.
        sub(/\A#{Regexp.escape(hi('usage:'))} /, '').
        split("\n").select{ |s| ! s.strip.empty? }
    end

    def syntax *args
      case args.length
      when 0; @syntax ||= "#{invocation_string} [opts] [args]"
      when 1; @syntax = args.first
      else raise ArgumentError.new("expecting 0 or 1 argument")
      end
    end

    def usage_string
      "#{hi('usage:')} #{syntax}"
    end

    module Nodeish
      def build_empty_option_parser
        OptionParser.new
      end
      def invite
        @err.puts "Try #{hi("#{invocation_string} -h")} for help."
        nil
      end
      def invocation_string
        "#{@parent.invocation_string} #{name}"
      end
      alias_method :path, :invocation_string
      def parent= parent
        @parent and fail("won't overwrite existing parent")
        @parent_protected_instance_methods = parent.class.protected_instance_methods(false).map(&:intern)
        @parent = parent
      end
      def usage msg=nil
        msg and @err.puts(msg)
        @err.puts usage_string
        invite
      end
      alias_method :empty_argv, :usage
    end
    include Nodeish

    module TreeDefiner
      def command_tree
        @command_tree ||= begin
          defined = command_definitions.map { |cls, a, b| cls.build(*a, &b) }
          defined_m = defined.map(&:method_symbol).compact
          implied_m = public_instance_methods(false).map(&:intern) - defined_m
          implied = implied_m.map { |m| Command.new(m) }
          Treeish[ defined + implied ]
        end
      end
      # this is nutty: for classes that extend this module, this is
      # something that is triggered when they are subclasses
      def inherited cls
        cls.on('-h', '--help', 'show this screen') { help }
        # You can rewrite the above in your class with another call to on()
        # If you want to remove it, try:
        #   option_definitions.reject! { |a,_| '-h' == a.first }
      end
      def namespace name, &block
        command_definitions.push [Namespace, [name], block]
      end
      def on *a, &b
        block_given? or raise ArgumentError.new("block required")
        option_definitions.push [a, b]
      end
      def option_definitions
        @option_definitions ||= []
      end
      def command_definitions
        @command_definitions ||= []
      end
      def method_added name
        if @grab_next_method
          command_definitions.last[1][0] = name.to_sym
          @grab_next_method = false
        end
      end
      def option_parser *a, &b
        block_given? or raise ArgumentError.new("block required")
        if a.empty?
          @grab_next_method and fail("can't have two anonymous " <<
          "command definitions in a row.")
          @grab_next_method = true
          a = [nil]
        end
        command_definitions.push [Command, a, b]
      end
      alias_method :o, :option_parser
    end

    module Treeish
      def self.[] ary
        ary.extend self
      end
      def ambiguous_command found, given
        usage("Ambiguous command: #{given.inspect}. " <<
          " Did you mean #{found.map{ |c| hi(c.name) }.join(' or ')}?")
      end
      def command_tree
        @command_tree ||= begin
          interface.command_tree.map { |c| c.parent = self; c } # careful
        end
      end
      def expecting
        interface.command_tree.map(&:name) * '|'
      end
      def find_command argv
        argv.empty? and return empty_argv # should be just for n/s
        given = argv.first
        matcher = Regexp.new(/\A#{Regexp.escape(given)}/)
        found = []
        interface.command_tree.each do |cmd|
          given == cmd.name and found = [cmd] and break
          matcher.match(cmd.name) and found.push(cmd)
        end
        case found.size
        when 0 ; unrecognized_command given
        when 1 ; found.first.for_run(self, argv.shift)
        else   ; ambiguous_command found, given
        end
      end
      Indent = '  '
      def help
        option_parser and @err.puts option_parser
        cmds = command_tree
        if cmds.any?
          @err.puts hi('commands:')
          rows = cmds.map { |c| { :name => c.name, :lines => c.summary } }
          w = rows.map{ |d| d[:name].length }.inject(0){ |m, l| m > l ? m : l }
          fmt = "%#{w}s  "
          rows.each do |row|
            @out.puts "#{Indent}#{hi(fmt % row[:name])}#{row[:lines].first}"
            row[:lines][1..-1].each do |line|
              @out.puts "#{Indent}#{fmt % ''}#{line}"
            end
          end
          @err.puts("Try #{hi("#{invocation_string} [cmd] -h")} for command help.")
        end
      end
      def option_parser
        @option_parser.nil? or return @option_parser
        op = build_empty_option_parser
        op.banner = usage_string
        if interface.option_definitions.any?
          shorts = interface.option_definitions.map do |args, block|
            op.on(*args) { instance_eval(&block) }
            args.first
          end
          op.banner << "\n       #{invocation_string} {#{shorts * '|'}}"
          op.banner << "\n" << hi('options:')
        end
        @option_parser = op
      end
      def run_opts argv
        begin
          option_parser.parse! argv
        rescue OptionParser::ParseError => e
          @err.puts highlight_header(e.to_s)
          invite
        end
        if argv.any?
          @err.puts "(#{hi('ignoring:')} #{argv.map(&:inspect).join(', ')})"
        end
        true
      end
      def unrecognized_command given
        usage("Unrecognized command: #{given.inspect}. Expecting: #{hi expecting}")
      end
      def usage_string
        "#{hi('usage:')} #{invocation_string} " <<
          "{#{interface.command_tree.map(&:name)*'|'}} [opts] [args]"
      end
    end

    class Namespace
      extend TreeDefiner, Colors
      include Treeish, Nodeish, Colors
      alias_method :interface, :class
      def init_for_run parent, name_as_used
        @name_as_used = name_as_used
        @parent = parent
        @out = @parent.out
        @err = @parent.err
      end
      attr_reader :out, :err
      def name
        interface.namespace_name
      end
      alias_method :inspect, :name
      def self.build name, &block
        name = name.to_s
        Class.new(self).class_eval do
          self.namespace_name = name
          x = class << self; self end
          x.send(:define_method, :inspect) { "#<#{name}:Namespace>" }
          x.send(:alias_method, :to_s, :inspect)
          class_eval(&block)
          self
        end
      end

      class << self
        def for_run parent, name_as_used
          namespace_runner = new
          namespace_runner.init_for_run parent, name_as_used
          namespace_runner
        end
        def method_symbol
          nil # for compat with etc
        end
        def name
          @namespace_name
        end
        def namespace_name= ns_name
          @namespace_name = ns_name.to_s
        end
        attr_reader :namespace_name
        def parent= parent
          @parent and fail("won't overwrite parent")
          @parent = parent
        end
        def summary
          a = command_tree.map { |c| hi(c.name) }
          ["child command#{'s' if a.length != 1}: {#{a * '|'}}"]
        end
      end
    end
  end
end

class Tmx::Face::Cli
  extend Tmx::Face::Command::TreeDefiner
  include Tmx::Face::Colors
  include Tmx::Face::Command::Nodeish
  include Tmx::Face::Command::Treeish

  def initialize
    @out = $stdout
    @err = $stderr
  end
  attr_reader :out, :err
  alias_method :interface, :class
  def argument_error e, cmd
    e.backtrace[0,2].detect { |s| s.match(/\A[^:]+/)[0] == __FILE__ } or raise e
    msg = e.message.sub(/\((\d+) for (\d+)\)\Z/) do
      "(#{$1.to_i - 1} for #{$2.to_i - 1})"
    end
    cmd.usage msg
  end
  def program_name
    @program_name ||= File.basename($PROGRAM_NAME)
  end
  alias_method :invocation_string, :program_name
  def run argv
    argv.empty?        and return empty_argv
    runner = self
    begin
      argv.first =~ /^-/ and return runner.run_opts(argv)
      cmd = runner.find_command(argv)
    end while (cmd and cmd.respond_to?(:find_command) and runner = cmd)
    cmd and req = cmd.parse(argv) and
    begin
      runner.send(cmd.method_symbol, req, * req.method_parameters)
    rescue ArgumentError => e
      argument_error e, cmd
    end
  end
  def version
    @err.puts hi([program_name, interface.version].compact.join(' '))
  end
  class << self
    def version *a, &block
      if a.any? and block
        raise ArgumentError.new("can't process args and block together.")
      elsif a.any? or block
        option_definitions.detect { |arr, _| '-v' == arr[0] } or
          on('-v', '--version', 'shows version') { version }
        if block
          @version = block
        else
          @version = a.length == 1 ? a.first : a
        end
      else
        @version.kind_of?(Proc) ? @version.call : @version
      end
    end
  end
end
