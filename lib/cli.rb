require "#{File.expand_path('../../vendor/face/cli', __FILE__)}"
require 'ruby-debug'

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

private
  def _app
    @app ||= begin
      require 'appscript'
      Appscript.app('iTerm')
    end
  end
end