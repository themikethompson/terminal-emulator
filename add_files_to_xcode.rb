#!/usr/bin/env ruby

# Script to automatically add Phase 3-10 files to Xcode project
# Usage: ruby add_files_to_xcode.rb

require 'xcodeproj'

# Configuration
PROJECT_PATH = 'macos/TerminalEmulator/TerminalEmulator.xcodeproj'
FILES_DIR = 'macos/TerminalEmulator/TerminalEmulator'
TARGET_NAME = 'TerminalEmulator'

# Files to add (organized by phase)
FILES_TO_ADD = {
  'Phase 3: Metal Rendering' => [
    'MetalRenderer.swift',
    'GlyphCache.swift',
    'Shaders.metal'
  ],
  'Phase 4: Advanced Graphics' => [
    'CursorRenderer.swift',
    'ScrollAnimator.swift',
    'VisualEffectsManager.swift',
    'LigatureHandler.swift'
  ],
  'Phase 5: Window Management' => [
    'TextSelection.swift',
    'ClipboardManager.swift',
    'TabManager.swift',
    'SplitPaneManager.swift',
    'SearchManager.swift'
  ],
  'Phase 6: Session Persistence' => [
    'SessionManager.swift',
    'WorkingDirectoryTracker.swift'
  ],
  'Phase 7: Plugin System' => [
    'PluginManager.swift'
  ],
  'Phase 8: AI Integration' => [
    'AIAssistant.swift'
  ],
  'Phase 9: Configuration' => [
    'ThemeManager.swift',
    'SettingsManager.swift'
  ],
  'Phase 10: Polish & Testing' => [
    'PerformanceMonitor.swift'
  ]
}

puts "=" * 60
puts "Xcode Project Integration Script"
puts "=" * 60
puts

# Check if xcodeproj gem is installed
begin
  require 'xcodeproj'
rescue LoadError
  puts "ERROR: xcodeproj gem not found!"
  puts "Install with: gem install xcodeproj"
  puts "Or: sudo gem install xcodeproj"
  exit 1
end

# Open the Xcode project
puts "Opening Xcode project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find the target
target = project.targets.find { |t| t.name == TARGET_NAME }
unless target
  puts "ERROR: Target '#{TARGET_NAME}' not found!"
  exit 1
end
puts "Found target: #{target.name}"
puts

# Find the main group (TerminalEmulator group in project navigator)
main_group = project.main_group.groups.find { |g| g.path == 'TerminalEmulator' } ||
             project.main_group['TerminalEmulator'] ||
             project.main_group

puts "Adding files to group: #{main_group.name || 'Main Group'}"
puts

# Track statistics
added_count = 0
skipped_count = 0
error_count = 0

# Add files
FILES_TO_ADD.each do |phase, files|
  puts "#{phase}:"

  files.each do |filename|
    file_path = File.join(FILES_DIR, filename)

    # Check if file exists on disk
    unless File.exist?(file_path)
      puts "  ✗ #{filename} - File not found on disk!"
      error_count += 1
      next
    end

    # Check if already in project
    existing_file = main_group.files.find { |f| f.path == filename }
    if existing_file
      puts "  ⊙ #{filename} - Already in project (skipped)"
      skipped_count += 1
      next
    end

    # Add file reference to group
    file_ref = main_group.new_file(filename)

    # Add to appropriate build phase
    if filename.end_with?('.swift')
      # Add to compile sources
      target.source_build_phase.add_file_reference(file_ref)
    elsif filename.end_with?('.metal')
      # Add to compile sources (Metal shaders)
      target.source_build_phase.add_file_reference(file_ref)
    end

    puts "  ✓ #{filename} - Added successfully"
    added_count += 1
  end

  puts
end

# Save the project
puts "Saving project..."
project.save

puts "=" * 60
puts "Integration Complete!"
puts "=" * 60
puts
puts "Summary:"
puts "  Added:   #{added_count} files"
puts "  Skipped: #{skipped_count} files (already in project)"
puts "  Errors:  #{error_count} files"
puts
puts "Total files processed: #{added_count + skipped_count + error_count}"
puts

if added_count > 0
  puts "✓ Files successfully added to Xcode project!"
  puts
  puts "Next steps:"
  puts "  1. Open Xcode: open #{PROJECT_PATH}"
  puts "  2. Build project: Cmd+B"
  puts "  3. Run and test: Cmd+R"
  puts
  puts "Expected: Metal renderer initialized successfully"
else
  puts "No new files were added."
end

puts
