module Skylab; end

module Skylab::Myterm

  class ValidationError < RuntimeError ; end

  module Color
    def alpha= mixed
      if mixed.kind_of?(String)
        md = /\A(\d+(?:\.\d+)?)%?\z/.match(mixed) or
          raise ValidationError.new("invalid format for percent #{val.inspect} -- expecting e.g. \"58%\"")
        mixed = md[1].to_f
      end
      (0.0..100.0).include?(mixed) or
        raise ValidationError.new("Percent value (#{mixed}%) must be between 0 and 100 inclusive.")
      self[3] = ChannelScalarNormalized[mixed / 100.0]
    end

    def to_hex
      '#' + self.map{ |x| int_to_hex(x) }.join('')
    end

    TARGET_PLACES = 2  # each component of an #rrggbb hexadecimal color has 2 places

    DIVISOR = 16 ** TARGET_PLACES

    def int_to_hex int
      int.respond_to?(:to_hex) and return int.to_hex
      (int.to_f / DIVISOR).round.to_s(16).rjust(TARGET_PLACES, '0')
    end
  end

  class << Color
    def [] obj
      obj.extend self
    end

    def dup color
      self[color.dup]
    end
  end

  module ChannelScalarNormalized
    def to_hex
      (('ff'.to_i(16).to_f * self).to_i).to_s(16).rjust(2, '0')
    end
  end

  class << ChannelScalarNormalized
    def [] obj
      obj.extend self
    end
  end

  class ImageBuilder
    def build_text_drawing img
      @lines.empty? and return fail("foo")
      #@todo setters for everything etc
      draw = Magick::Draw.new
      draw.gravity         = @opts[:gravity] || Magick::NorthEastGravity
      @opts[:fill] ||= '#662020'
      @opts[:fill].kind_of?(Proc) and @opts[:fill] = @opts[:fill].call(self)
      draw.fill            = @opts[:fill]
      draw.font            = @opts[:font] || "#{ENV['HOME']}/.fonts/SimpleLife.ttf"
      draw.font_style      = @opts[:font_style] || Magick::NormalStyle
      draw.pointsize       = @opts[:point_size] || 60
      draw.text_antialias  = @opts.key?(:text_antialias) ? @opts[:text_antialias] : true
      draw.annotate(img, 0,0,20,10, @lines.first)
      if @lines.length > 1
        second_line = @lines[1..-1].join(' ')
        draw.annotate(img, 0,0,20,80, second_line) do
          self.pointsize = 30
        end
      end
      nil # draw not needed at this point
    end
    private :build_text_drawing

    def initialize iterm, lines, opts
      @iterm, @lines, @opts = [iterm, lines, opts]
    end

    attr_reader :iterm

    def run
      require 'RMagick'
      bg_color = Color.dup(@iterm.session.background_color)
      @opts.key?(:alpha_percent) and bg_color.alpha = @opts[:alpha_percent]
      img = Magick::Image.new(500, 300) do # copying over hard-coded dimensions from original Dmytro script
        self.background_color = bg_color.to_hex
      end
      build_text_drawing img
      img
    end
  end

  class << ImageBuilder
    def build_background_image iterm, lines, opts
      new(iterm, lines, opts).run
    end
  end

  class ItermProxy
    # ItermProxy is a wrapper around everything Iterm to the extent that its AppleScript interface supports
    #
    MIN_LEN = 50

    def app
      @app ||= begin
        require 'appscript'
        Appscript.app('iTerm')
      end
    end
    private :app

    def invalid msg
      raise ValidationError.new(msg)
    end
    private :invalid

    def bounds= arr
      x = arr.detect { |i| i.to_s !~ /^\d+$/ } and return invalid("expecting digit had #{x.inspect}")
      x = arr[2,2].detect { |i| i.to_i < MIN_LEN } and return invalid("too small: #{x} (min: #{MIN_LEN})")
      app.windows[0].bounds.set arr
    end

    def bounds
      app.windows[0].bounds.get
    end

    def session
      tty = `tty`.strip
      @session ||= begin
        session = catch(:catch_two) do
          app.terminals.get.each do |term|
            sessions = term.sessions.get
            sessions.each do |session|
              if session.tty.get == tty
                throw :catch_two, session
              end
            end
          end
        end
        session or fail("couldn't ascertain current session!")
        SessionProxy.new(session)
      end
    end
  end

  module AppscriptDelegator
    def delegated_attr_readers *list
      list.each do |property|
        lambda do |_property|
          define_method(_property) do
            @resource.send(_property).get
          end
        end.call(property)
      end
    end

    def delegated_attr_writers *list
      list.each do |property|
        lambda do |_property|
          define_method("#{_property}=") do |val|
            @resource.send(_property).set val
          end
        end.call(property)
      end
    end

    def delegated_attr_accessors *list
      delegated_attr_readers(*list)
      delegated_attr_writers(*list)
    end
  end

  class ItermProxy::SessionProxy
    extend AppscriptDelegator

    delegated_attr_accessors :background_image_path

    def background_color
      Color[@resource.background_color.get]
    end

    def foreground_color
      Color[@resource.foreground_color.get]
    end

    def initialize session
      @resource = session
    end

    delegated_attr_readers :tty
  end
end

module Skylab
  class << Myterm
    def version
      File.read(File.expand_path('../../../VERSION', __FILE__))
    end
  end
end

