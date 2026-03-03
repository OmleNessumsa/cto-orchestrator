#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |t| t.name == 'RickTerminal' }

# Check if UI test target already exists
existing_target = project.targets.find { |t| t.name == 'RickTerminalUITests' }

if existing_target
  puts "⚠️  RickTerminalUITests target already exists!"
  exit 0
end

# Create UI test target
ui_test_target = project.new_target(:ui_test_bundle, 'RickTerminalUITests', :macos, '13.0')

# Get the UI test files group
ui_test_group = project.main_group.find_subpath('RickTerminalUITests', true)
ui_test_group.set_source_tree('SOURCE_ROOT')

# Add test files to the target
test_files = [
  'RickTerminalUITests/AppLaunchTests.swift',
  'RickTerminalUITests/TerminalInteractionTests.swift',
  'RickTerminalUITests/FileBrowserTests.swift',
  'RickTerminalUITests/KanbanBoardTests.swift'
]

test_files.each do |file_path|
  file_ref = ui_test_group.new_reference(file_path)
  ui_test_target.add_file_references([file_ref])
end

# Set build settings
ui_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.rickportal.RickTerminalUITests'
  config.build_settings['TEST_TARGET_NAME'] = 'RickTerminal'
end

# Add dependency on main app target
ui_test_target.add_dependency(main_target)

# Save the project
project.save

puts "✅ Successfully added RickTerminalUITests target!"
puts ""
puts "Test files added:"
test_files.each { |f| puts "  - #{f}" }
puts ""
puts "Next steps:"
puts "1. Open Xcode: open RickTerminal.xcodeproj"
puts "2. Select RickTerminalUITests scheme"
puts "3. Run tests: Cmd+U"
