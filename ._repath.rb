#!/usr/bin/env ruby

payload = lambda do

  bin_folder="#{`pwd`.strip}/bin"
  unless File.directory?(bin_folder)
    return {
      :message => "not a directory, won't add to PATH: #{bin_folder}"
    }
  end

  path = ENV['PATH']
  path_parts = path.split(':')

  if path.include?(bin_folder)
    if true or ARGV.include?('-F')
      unless path_parts.reject! { |p| p == bin_folder }
        return {
          :message => "bin folder \"#{bin_folder}\" not found in path \"#{path}\""
        }
      end
      return {
        :new_path => ( [bin_folder] + [path_parts] ).join(':'),
        :message  => "rewriting path to have bin folder at the beginning",
        :success => true
      }
    else
      if 0 == path.index(bin_folder)
        return {
          :message => "bin folder is already at front of PATH",
          :success => true
        }
      else
        return {
          :message => "bin folder is in path but not at front.  use -F to rewrite PATH",
          :status => :not_front,
          :success => true
        }
      end
    end
  else
    path_parts.unshift(bin_folder)
    return {
      :new_path => path_parts.join(':'),
      :message  => "prepending bin folder to the beginning of the PATH.",
      :success  => true
    }
  end

end.call

payload[:message] and $stdout.puts "echo #{payload[:message].inspect}"
payload[:new_path] and $stdout.puts "export PATH=\"#{payload[:new_path]}\""
$stdout.puts(payload[:success] ? "echo 'hack done.'" : "echo 'hack failed.'")
