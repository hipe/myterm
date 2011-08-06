require "#{File.expand_path('../vendor/face/cli', __FILE__)}"
require "#{File.dirname(__FILE__)}/api"
require 'ruby-debug'
require 'open3'

module Skylab; end
module Skylab::Myterm; end

module Skylab::Myterm::PathPrettifier
  HomeDirRe = /\A#{Regexp.escape(ENV['HOME'])}/
protected
  def pretty_path path
    path.sub(HomeDirRe, '~')
  end
end

class Skylab::Face::Command
  include Skylab::Myterm::PathPrettifier
end

class Skylab::Myterm::Cli < Skylab::Face::Cli
  Myterm = ::Skylab::Myterm # don't use fully qualified name internally
  include Myterm::PathPrettifier

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
    syntax "#{path} [opts] [<text> [<text> [...]]]"
    o.banner = "Generate a background image with certain text for the terminal\n#{usage_string}"
    o.on('-e', '--exec <cmd ...>', 'Execute <cmd ...> in shell, also use it as text for background.') { }
    o.on('-o', '--opacity PERCENT', "Percent by which to make image background opaque",
      "(0%: tranparent. 100%: solid.  Default: solid)") { |amt| req[:alpha_percent] = amt }
    req[:font_file] = DefaultFontFile
    o.on('--font FONTFILE.ttf', "font to use (default: #{pretty_path(req[:font_file])})") do |path|
      req[:font_file] = path
    end
    req[:fill] = '#662020'
    o.on('--fill[=COLOR]', "Write text in this color (default: #{req[:fill].inspect})",
      "(when present but with no value, will use \"Text/Normal\" setting of current iTerm tab)" ) do |v|
      req[:fill] = v || lambda { |img| img.iterm.session.foreground_color.to_hex }
    end
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
        args.any? and fail("logic error -- see before_parse_bg.")
        args = req[:_exec_this]
      else
        return get_background
      end
    end
    check_font(req) or return
    img = Myterm::ImageBuilder.build_background_image(iterm, args, req) or return false
    req[:verbose] and @err.puts "(bg_color: #{img.background_color.inspect})"
    outpath = "#{ImgDirname}/#{ImgBasename}.#{Process.pid}.png"
    img.write(outpath)
    req[:verbose] and @err.puts "(setting background image to: #{outpath})" # doesn't care if --verbose
    iterm.session.background_image_path = outpath
    if req[:_exec_this]
      @err.puts "(#{program_name} executing: #{req[:_exec_this].join(' ')})"
      exec(req[:_exec_this].join(' '))
    end
    true
  end

  DefaultFontFile = "#{ENV['HOME']}/.fonts/MytermDefaultFont.ttf"
  ImgDirname  = '/tmp'
  ImgBasename = 'iTermBG'

private
  def check_font req
    File.exist?(req[:font_file]) and return true
    if req[:font_file] == DefaultFontFile
      return maybe_download_font req
    else
      font_not_found req
    end
  end

  DefaultFontUrl              = 'http://img.dafont.com/dl/?f=simple_life'
  DefaultFontFileNotSimlinked = "#{ENV['HOME']}/.fonts/SimpleLife.ttf"

  def maybe_download_font req
    target = DefaultFontFileNotSimlinked
    File.exist?(target) and return true
    $stdin.tty? && $stdout.tty? or return font_not_found(req)
    @err.write "Font file #{pretty_path(req[:font_file])} not found.  "
    require 'highline'
    require 'fileutils'
    HighLine.new.agree("Let #{program_name} download it? (Y/n) (recommended: yes)") or return false
    outfile = DefaultFontFileNotSimlinked.sub(/\.ttf$/, '.zip')
    font_dir = File.dirname(outfile)
    File.directory?(font_dir) or FileUtils.mkdir_p(font_dir, :verbose => true)
    cmds = ["wget -O #{outfile} #{DefaultFontUrl}"]
    cmds.push "cd #{font_dir}"
    cmds.push "unzip #{outfile}"
    cmds.push "ln -s #{DefaultFontFileNotSimlinked} #{DefaultFontFile}"
    cmds.push("echo 'finished installing for #{program_name}: #{pretty_path(DefaultFontFileNotSimlinked)}. " <<
      "Please try using it again.'")
    @err.puts(cmd = cmds.join(' ; '))
    exec(cmd)
  end

  def font_not_found req
    @err.puts "font file not found: #{pretty_path(req[:font_file])}"
    req.command.usage
    return false
  end

  def iterm
    @iterm ||= Myterm::ItermProxy.new
  end

  def get_background
    @err.puts "tty: #{iterm.session.tty}"
    @err.puts "background_image: #{iterm.session.background_image_path.inspect}"
    @err.puts "background_color: #{iterm.session.background_color}"
  end

end
