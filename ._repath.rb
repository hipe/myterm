#!/usr/bin/env ruby

payload = lambda do

  dir = File.expand_path('../bin', __FILE__)
  File.directory?(dir) or return {
    :message => "not a directory, won't add to PATH: #{dir}"
  }

  path = ENV['PATH']
  parts = path.split(':')
  case parts.index(dir)
  when nil
    {
      :new_path => ([dir] + parts).join(':'),
      :message  => "prepending bin folder to the beginning of the PATH.",
      :success  => true
    }
  when 0
    { :message  => "already at front of path: \"#{dir}\"",
      :success  => true
    }
  else
    {
      :new_path => ([dir] + parts.reject{ |x| x == path }).join(':'),
      :message  => "rewriting path to have bin folder at the beginning",
      :success  => true
    }
  end

end.call

payload[:message] and $stdout.puts "echo #{payload[:message].inspect}"
payload[:new_path] and $stdout.puts "export PATH=\"#{payload[:new_path]}\""
$stdout.puts(payload[:success] ? "echo 'hack done.'" : "echo 'hack failed.'")
