require "#{File.expand_path('../vendor/face/cli', __FILE__)}"
require 'ruby-debug'
require 'open3'

module Skylab; end
module Skylab::Myterm; end
class Skylab::Myterm::Cli < Tmx::Face::Cli
  Myterm = ::Skylab::Myterm # don't use fully qualified name internally

  version do
    require "#{File.dirname(__FILE__)}/version"
    Myterm::VERSION
  end

  o(:bounds) do |o|
    syntax "#{path} [x y width height]"
    o.banner = "gets/sets the bounds of the terminal window\n#{usage_string}"
  end

  def bounds o, *a
    case a.length
    when 4
      begin ; iterm.bounds = a ; rescue Myterm::ValidationError => e ; return usage e ; end
    when 0
      @err.puts iterm.bounds.inspect
    else
      return usage("bad number of args #{a.length}: expecting 0 or 4")
    end
  end

  o(:'bg') do |o, req|
    syntax "#{path} [<text> [<text> [...]]]"
    o.banner = "Create and set a background image for the teriminal\n#{usage_string}"
    o.on('-e', '--exec <cmd ...>', 'Display <cmd ...> in the background then execute it in the shell.') { }
    o.on('-o', '--opacity PERCENT', "Percent by which to make image background opaque",
      "(0%: tranparent. 100%: solid.  Default: solid)") { |amt| req[:alpha_percent] = amt }
    o.on('-v', '--verbose', 'Be verbose.') { req[:verbose] = true }
  end

  def before_parse_bg req, args
    idx = args.index { |s| %w(-e --exec).include?(s) } or return true
    req[:_exec_this] = args[(idx+1)..-1]
    args.replace idx == 0 ? [] : args[0..(idx-1)]
    true
  end
  protected :before_parse_bg

  def bg req, *args
    if args.empty?
      if req[:_exec_this]
        args = req[:_exec_this]
      else
        return _bg_get
      end
    end
    normalize_bg_options(req) or return
    argv = argv_for_image_magick req, args
    cmd = argv.join(' ')
    pid = nil
    req[:verbose] and @err.puts cmd
    Open3.popen3(cmd) do |sin, sout, serr|
      err = serr.read
      out = sout.read
      /\A\d+[[:space:]]*\z/ =~ out or fail("unexpected stdout from convert: #{out.inspect}")
      "" == err or return @err.puts "unexpected error from `convert`:\n#{err}"
      pid = out.to_i
    end
    path = "#{ImgDirname}/#{ImgBasename}.#{pid}.png"
    @err.puts "(setting background image to: #{path})" # doesn't care if --verbose
    _current_session.background_image_path.set path
    if req[:_exec_this]
      @err.puts "(#{req[:_exec_this].join(' ')})"
      exec(req[:_exec_this].join(' '))
    end
    true
  end

  ImgDirname  = '/tmp'
  ImgBasename = 'iTermBG'
  ChannelFull = 65535

private
  def iterm
    @iterm ||= Myterm::ItermProxy.new
  end

  module Color
    def self.[] obj
      obj.extend self
    end
    def to_hex
      '#' + self.map{ |x| int_to_hex(x) }.join('')
    end
    TargetPlaces = 2  # each component of an #rrggbb hexadecimal color has 2 places
    Divisor = 16 ** TargetPlaces
    def int_to_hex int
      (int.to_f / Divisor).round.to_s(16).rjust(TargetPlaces, '0')
    end
  end

  def argv_for_image_magick req, lines
    lines.reject! { |l| l.index("'") }
    offset1 = "20,10"
    offset2 = "20,80"
    argv = ['convert']
    argv.push "-size 500x300"
    clr = __bg_color_get
    req[:verbose] and @err.puts "bg_color: #{clr.inspect}"
    bg_hex = if req.key?(:alpha_percent)
      "#{clr.to_hex}#{req[:alpha_percent].to_hex}"
    else
      clr.to_hex
    end
    argv.push "xc:#{bg_hex}"
    argv.push "-gravity NorthEast"
    argv.push "-fill \"#{'#662020'}\""
    # argv.push "-fill #{'#'}" # just to get any error
    argv.push "-font #{ENV['HOME']}/.fonts/SimpleLife.ttf"
    argv.push "-style Normal"
    argv.push "-pointsize 60"
    argv.push "-antialias"
    argv.push "-draw \"text #{offset1} '#{lines[0]}'\""
    if lines.length > 1
      second_line = lines[1..-1].join(' ')
      argv.push "-pointsize 30 -draw \"text #{offset2} '#{second_line}'\""
    end
    argv.push "#{ImgDirname}/#{ImgBasename}.$$.png; echo $$"
    argv
  end

  def _bg_get
    session = _current_session
    @err.puts "tty: #{_my_tty}"
    @err.puts "background_image: #{session.background_image_path.get.inspect}"
    @err.puts "background_color: #{session.background_color.get}"
  end

  def __bg_color_get
    Color[_current_session.background_color.get]
  end

  def _current_session
    @current_session ||= _app.terminals.get.each do |term|
      sessions = term.sessions.get
      sessions.each do |session|
        if session.tty.get == _my_tty
          return session
        end
      end
    end
    nil
  end

  def _my_tty
    @my_tty ||= `tty`.strip
  end

  module ChannelScalarNormalized
    def self.[] obj
      obj.extend self
    end
    def to_hex
      (('ff'.to_i(16).to_f * self).to_i).to_s(16).rjust(2, '0')
    end
  end

  def normalize_alpha_percent req
    if val = req[:alpha_percent]
      if md = /\A(\d+(?:\.\d+)?)%?\z/.match(val)
        val = md[1].to_f
        if (0.0..100.0).include?(val)
          req[:alpha_percent] = ChannelScalarNormalized[val / 100.0]
        else
          return @err.puts("Percent value (#{val}%) must be between 0 and 100 inclusive.")
        end
      else
        return @err.puts("invalid format for percent #{val.inspect} -- expecting e.g. \"58%\"")
      end
    end
    true
  end

  def normalize_bg_options req
    req.key?(:alpha_percent) and (normalize_alpha_percent(req) or return false)
    true
  end
end

class Skylab::Myterm::ValidationError < RuntimeError ; end

class Skylab::Myterm::ItermProxy
  # ItermProxy is a wrapper around everything Iterm to the extent that its AppleScript interface supports

  Myterm = ::Skylab::Myterm # keep top level name out of the bulk of the code

  MinLen = 50

  def bounds= arr
    x = arr.detect { |i| i.to_s !~ /^\d+$/ } and return invalid("expecting digit had #{x.inspect}")
    x = arr[2,2].detect { |i| i.to_i < MinLen } and return invalid("too small: #{x} (min: #{MinLen})")
    app.windows[0].bounds.set arr
  end

  def bounds
    app.windows[0].bounds.get
  end

private

  def app
    @app ||= begin
      require 'appscript'
      Appscript.app('iTerm')
    end
  end

  def invalid msg
    raise Myterm::ValidationError.new(msg)
  end
end
