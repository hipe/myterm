require "#{File.expand_path('../../vendor/face/cli', __FILE__)}"
require 'ruby-debug'
require 'open3'

module Skylab; end
module Skylab::Iterm; end
class Skylab::Iterm::Cli < Tmx::Face::Cli

  o(:bounds) do |o|
    syntax "#{path} [x y width height]"
    o.banner = "gets/sets the bounds of the terminal window\n#{usage_string}"
  end

  MinLen = 50

  def bounds o, *a
    case a.length
    when 4
      x = a.detect { |i| i !~ /^\d+$/ } and return usage("expecting digit had #{x.inspect}")
      x = a[2,2].detect { |i| i.to_i < MinLen } and return usage("too small: #{x} (min: #{MinLen})")
      @err.puts _app.windows[0].bounds.set a
    when 0
      @err.puts _app.windows[0].bounds.get.inspect
    else
      return usage("bad number of args #{a.length}: expecting 0 or 4")
    end
  end

  o(:'bg') do |o|
    syntax "#{path} [<text> [<text> [...]]]"
    o.banner = "create and set a background image for the teriminal\n#{usage_string}"
  end

  def bg req, *args
    args.empty? and return _bg_get
    argv = _bg args
    cmd = argv.join(' ')
    pid = nil
    Open3.popen3(cmd) do |sin, sout, serr|
      err = serr.read
      out = sout.read
      /\A\d+[[:space:]]*\z/ =~ out or fail("unexpected stdout from convert: #{out.inspect}")
      "" == err or return @err.puts "unexpected error from `convert`:\n#{err}"
      pid = out.to_i
    end
    path = "#{ImgDirname}/#{ImgBasename}.#{pid}.png"
    @err.puts "(setting background image to: #{path})"
    _current_session.background_image_path.set path
  end

  ImgDirname  = '/tmp'
  ImgBasename = 'iTermBG'
  ChannelFull = 65535

private
  module Color
    def self.[] obj
      obj.extend self
    end
    def to_hex
      '#' + self.map{ |x| x.to_s(16)[0,2] }.join('')
    end
  end
  def _app
    @app ||= begin
      require 'appscript'
      Appscript.app('iTerm')
    end
  end

  def _bg lines
    lines.reject! { |l| l.index("'") }
    offset1 = "20,10"
    offset2 = "20,80"
    argv = ['convert']
    argv.push "-size 500x300"
    bg_hex = __bg_color_get.to_hex
    argv.push "xc:#{bg_hex}"
    argv.push "-gravity NorthEast"
    argv.push "-fill \"#{'#662020'}\""
    # argv.push "-fill #{'#'}" # just to get any error
    argv.push "-font #{ENV['HOME']}/.fonts/SimpleLife.ttf"
    argv.push "-style Normal"
    argv.push "-pointsize 60"
    argv.push "-antialias"
    argv.push "-draw \"text #{offset1} '#{lines[0]}'\""
    if lines[1]
      argv.push "-pointsize 30 -draw \"text #{offset2} '#{lines[1]}'\""
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
end