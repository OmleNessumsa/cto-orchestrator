#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |t| t.name == 'RickTerminal' }

# Check if unit test target already exists
existing_target = project.targets.find { |t| t.name == 'RickTerminalTests' }

if existing_target
  puts "⚠️  RickTerminalTests target already exists!"
  exit 0
end

# Create unit test target
unit_test_target = project.new_target(:unit_test_bundle, 'RickTerminalTests', :macos, '13.0')

# Get or create the test files group
test_group = project.main_group.find_subpath('RickTerminalTests', false)
unless test_group
  test_group = project.main_group.new_group('RickTerminalTests', 'RickTerminalTests')
end

# Find all test files
test_dir = File.join(File.dirname(project_path), 'RickTerminalTests')
test_files = Dir.glob(File.join(test_dir, '*.swift')).map { |f| File.basename(f) }

puts "Found #{test_files.length} test files"

# Add test files to the target
test_files.each do |filename|
  file_path = "RickTerminalTests/#{filename}"

  # Check if file reference already exists in group
  existing_ref = test_group.files.find { |f| f.path == filename }

  unless existing_ref
    file_ref = test_group.new_file(file_path)
    unit_test_target.source_build_phase.add_file_reference(file_ref)
    puts "  + Added: #{filename}"
  else
    unit_test_target.source_build_phase.add_file_reference(existing_ref)
    puts "  ~ Existing: #{filename}"
  end
end

# Set build settings
unit_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.rickportal.RickTerminalTests'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/RickTerminal.app/Contents/MacOS/RickTerminal'
  config.build_settings['INFOPLIST_FILE'] = ''
end

# Add dependency on main app target
unit_test_target.add_dependency(main_target)

# Add to main scheme for testing
scheme_path = File.join(project_path, 'xcshareddata', 'xcschemes', 'RickTerminal.xcscheme')
if File.exist?(scheme_path)
  # Read and modify scheme to include tests
  scheme_content = File.read(scheme_path)

  # Check if testable reference already exists
  unless scheme_content.include?('RickTerminalTests')
    # Find the TestAction section and add testable reference
    test_action_insert = <<-XML
            <TestableReference
               skipped = "NO"
               parallelizable = "YES">
               <BuildableReference
                  BuildableIdentifier = "primary"
                  BlueprintIdentifier = "#{unit_test_target.uuid}"
                  BuildableName = "RickTerminalTests.xctest"
                  BlueprintName = "RickTerminalTests"
                  ReferencedContainer = "container:RickTerminal.xcodeproj">
               </BuildableReference>
            </TestableReference>
    XML

    # Insert before </Testables>
    scheme_content.sub!('</Testables>', "#{test_action_insert}</Testables>")
    File.write(scheme_path, scheme_content)
    puts "✅ Added RickTerminalTests to scheme"
  end
end

# Save the project
project.save

puts ""
puts "✅ Successfully added RickTerminalTests target!"
puts ""
puts "Test files added: #{test_files.length}"
puts ""
puts "Next steps:"
puts "1. Run: xcodebuild test -scheme RickTerminal -destination 'platform=macOS'"
puts "2. Or open Xcode and press Cmd+U"
