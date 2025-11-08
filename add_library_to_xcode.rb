#!/usr/bin/env ruby

require 'xcodeproj'

PROJECT_PATH = 'macos/TerminalEmulator/TerminalEmulator.xcodeproj'
TARGET_NAME = 'TerminalEmulator'

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find the target
target = project.targets.find { |t| t.name == TARGET_NAME }
unless target
  puts "ERROR: Target '#{TARGET_NAME}' not found!"
  exit 1
end

puts "Found target: #{target.name}"

# Add -lterminal_core to OTHER_LDFLAGS
target.build_configurations.each do |config|
  flags = config.build_settings['OTHER_LDFLAGS'] || []
  flags = [flags] if flags.is_a?(String)

  unless flags.include?('-lterminal_core')
    flags << '-lterminal_core'
    config.build_settings['OTHER_LDFLAGS'] = flags
    puts "Added -lterminal_core to #{config.name} configuration"
  else
    puts "#{config.name} configuration already has -lterminal_core"
  end
end

puts "Saving project..."
project.save

puts "Done! Library linker flag added."
