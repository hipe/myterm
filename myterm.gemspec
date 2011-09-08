# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'myterm/api'

Gem::Specification.new do |s|
  s.name        = "myterm"
  s.version     = Skylab::Myterm.version
  s.authors     = ["Mark Meves"]
  s.email       = ["mark.meves@gmail.com"]
  s.homepage    = "http://botnoise.org"
  s.summary     = %q{Command line interface for customizing iTerm using AppleScript}
  s.description = %q{Command line interface for customizing iTerm using AppleScript.
    Creates meaningful, salient, eye-catching background images that help to discern between iTerm windows.}.gsub(/\n */, ' ')

  s.rubyforge_project = "myterm"

  s.add_dependency 'rb-appscript'
  s.add_dependency 'highline'
  s.add_dependency 'rmagick'
  s.add_development_dependency "ruby-debug19"

  s.files         = `git ls-files`.split("\n")
  # s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
