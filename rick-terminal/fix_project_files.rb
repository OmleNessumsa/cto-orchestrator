#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

project_path = '/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal.xcodeproj'
project_root = '/Users/elmo.asmussen/Projects/CTO/rick-terminal'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |t| t.name == 'RickTerminal' }

puts "Removing all file references from build phase..."
# Remove all broken file references from build phase
main_target.source_build_phase.files.to_a.each do |build_file|
  if build_file.file_ref && build_file.file_ref.real_path
    unless File.exist?(build_file.file_ref.real_path)
      puts "  Removing broken: #{build_file.file_ref.path}"
      build_file.remove_from_project
    end
  end
end

# Find all Swift files in RickTerminal directory
all_swift_files = Dir.glob("#{project_root}/RickTerminal/**/*.swift")

# Get all file references currently in project that actually work
existing_files = []
main_target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.real_path && File.exist?(build_file.file_ref.real_path)
    existing_files << build_file.file_ref.real_path.to_s
  end
end

puts "\nFound #{all_swift_files.length} Swift files in filesystem"
puts "Project has #{existing_files.length} valid source files"

# Find files that need to be added
files_to_add = all_swift_files.select do |file|
  !existing_files.any? { |ef| ef == file }
end

puts "\nAdding #{files_to_add.length} files to project..."

# Helper to find or create group path
def find_or_create_group(project, path_from_root)
  parts = path_from_root.split('/')
  current_group = project.main_group

  parts.each do |part|
    next if part.empty?
    found = current_group.children.find do |child|
      child.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
      child.display_name == part
    end

    if found
      current_group = found
    else
      new_group = current_group.new_group(part, part)
      current_group = new_group
    end
  end

  current_group
end

files_to_add.each do |file_path|
  # Get relative path from project root
  relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(project_root)).to_s

  # Split into directory and filename
  dir_path = File.dirname(relative_path)
  filename = File.basename(file_path)

  puts "  Adding: #{relative_path}"

  # Find or create the group
  group = find_or_create_group(project, dir_path)

  # Add file reference with correct path
  file_ref = group.new_file(file_path)

  # Add to target
  main_target.add_file_references([file_ref])
end

# Save the project
project.save

puts "\n✅ Project fixed - added #{files_to_add.length} files"
