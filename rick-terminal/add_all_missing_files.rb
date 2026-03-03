#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

project_path = '/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal.xcodeproj'
project_root = '/Users/elmo.asmussen/Projects/CTO/rick-terminal'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |t| t.name == 'RickTerminal' }

# Find all Swift files in RickTerminal directory
all_swift_files = Dir.glob("#{project_root}/RickTerminal/**/*.swift")

# Get all file references currently in project
existing_files = []
main_target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.real_path
    existing_files << build_file.file_ref.real_path.to_s
  end
end

puts "Found #{all_swift_files.length} Swift files"
puts "Project has #{existing_files.length} source files"

# Find files that need to be added
files_to_add = all_swift_files.select do |file|
  !existing_files.any? { |ef| ef.end_with?(File.basename(file)) }
end

puts "\nNeed to add #{files_to_add.length} files:"

files_to_add.each do |file_path|
  relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(project_root))
  puts "  - #{relative_path}"

  # Find or create the appropriate group
  path_parts = relative_path.to_s.split('/')
  path_parts.pop # Remove filename

  current_group = project.main_group
  path_parts.each do |part|
    next_group = current_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.path == part }
    if next_group.nil?
      next_group = current_group.new_group(part)
    end
    current_group = next_group
  end

  # Add file reference
  file_ref = current_group.new_reference(File.basename(file_path))
  file_ref.source_tree = '<group>'

  # Add to target
  main_target.add_file_references([file_ref])
end

# Save the project
project.save

puts "\n✅ Added #{files_to_add.length} files to project"
