#!/usr/bin/env ruby

# Fix file path references in Xcode project
require 'xcodeproj'

PROJECT_PATH = 'macos/TerminalEmulator/TerminalEmulator.xcodeproj'

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Files that need path fixing
FILES_TO_FIX = [
  'AppDelegate.swift',
  'TerminalCore.swift',
  'TerminalWindowController.swift',
  'TerminalViewController.swift',
  'TerminalView.swift'
]

puts "Fixing file references..."

project.main_group.recursive_children.each do |item|
  next unless item.is_a?(Xcodeproj::Project::Object::PBXFileReference)

  if FILES_TO_FIX.include?(item.path)
    puts "  Fixing: #{item.path}"
    # Set the correct path - files are in TerminalEmulator subdirectory
    item.path = "TerminalEmulator/#{item.path}"
  end
end

puts "Saving project..."
project.save

puts "Done! File references fixed."
