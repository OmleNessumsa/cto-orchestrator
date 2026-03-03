#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |t| t.name == 'RickTerminal' }

# Remove all references to CardDetailView
project.main_group.recursive_children.each do |item|
  if item.is_a?(Xcodeproj::Project::Object::PBXFileReference) && item.path&.include?('CardDetailView')
    puts "Removing: #{item.real_path}"
    item.remove_from_project
  end
end

# Find the Views group
views_group = nil
project.main_group.recursive_children.each do |item|
  if item.is_a?(Xcodeproj::Project::Object::PBXGroup) && item.path == 'Views' && item.hierarchy_path.include?('Kanban')
    views_group = item
    break
  end
end

if views_group
  puts "Found Views group"
  # Add the file correctly
  file_ref = views_group.new_reference('CardDetailView.swift')
  file_ref.source_tree = '<group>'
  main_target.add_file_references([file_ref])
  puts "✅ Added CardDetailView.swift with correct path"
else
  puts "⚠️  Views group not found"
end

# Save the project
project.save

puts "✅ Project updated"
