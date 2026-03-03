#!/bin/bash

# Script to add Preferences files to Xcode project
# These files need to be added manually in Xcode:
# 1. Open RickTerminal.xcodeproj in Xcode
# 2. Right-click on RickTerminal group in project navigator
# 3. Select "Add Files to RickTerminal..."
# 4. Navigate to RickTerminal/Preferences/ folder
# 5. Select all .swift files:
#    - PreferencesView.swift
#    - GeneralPreferencesView.swift
#    - AppearancePreferencesView.swift
#    - TerminalPreferencesView.swift
#    - ClaudeIntegrationPreferencesView.swift
#    - KeyboardShortcutsPreferencesView.swift
# 6. Make sure "Copy items if needed" is UNCHECKED
# 7. Make sure "RickTerminal" target is CHECKED
# 8. Click "Add"

echo "Files to add to Xcode project:"
echo "=============================="
find RickTerminal/Preferences -name "*.swift" -type f

echo ""
echo "Instructions:"
echo "1. Open RickTerminal.xcodeproj in Xcode"
echo "2. Right-click 'RickTerminal' group → Add Files to RickTerminal..."
echo "3. Select all files in RickTerminal/Preferences/"
echo "4. Ensure 'RickTerminal' target is checked"
echo "5. Click Add"
