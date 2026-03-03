#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |t| t.name == 'RickTerminal' }

# Find Kanban Views group or create it
kanban_group = project.main_group.find_subpath('RickTerminal/Kanban/Views', false)

if kanban_group.nil?
  puts "Creating Kanban/Views group"
  rick_terminal_group = project.main_group.find_subpath('RickTerminal', true)
  kanban_parent = rick_terminal_group.find_subpath('Kanban', true)
  kanban_group = kanban_parent.new_group('Views')
end

# Add CardDetailView.swift if not already added
card_detail_path = 'RickTerminal/Kanban/Views/CardDetailView.swift'

# Check if file reference already exists
existing_ref = kanban_group.files.find { |f| f.path == 'CardDetailView.swift' }

if existing_ref.nil?
  puts "Adding CardDetailView.swift to project"
  file_ref = kanban_group.new_reference(card_detail_path)
  main_target.add_file_references([file_ref])
  puts "✅ Added CardDetailView.swift"
else
  puts "CardDetailView.swift already in project"
end

# Save the project
project.save

puts "✅ Project updated successfully"
