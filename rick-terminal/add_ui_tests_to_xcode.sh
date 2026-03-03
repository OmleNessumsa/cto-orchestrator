#!/bin/bash

# Script to add RickTerminalUITests target to Xcode project
# This script uses PlistBuddy and manual project.pbxproj editing

PROJECT_DIR="/Users/elmo.asmussen/Projects/CTO/rick-terminal"
PROJECT_FILE="$PROJECT_DIR/RickTerminal.xcodeproj/project.pbxproj"
UITEST_DIR="$PROJECT_DIR/RickTerminalUITests"

echo "Adding RickTerminalUITests target to Xcode project..."

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Note: Manually editing project.pbxproj is complex and error-prone
# The recommended approach is to open Xcode and add the target manually
# However, we'll provide the basic structure

echo "⚠️  Manual step required:"
echo ""
echo "To complete the UI test setup, please open Xcode and:"
echo "1. File -> New -> Target"
echo "2. Select 'UI Testing Bundle'"
echo "3. Name it 'RickTerminalUITests'"
echo "4. Set target to 'RickTerminal'"
echo "5. Click Finish"
echo "6. Delete the auto-generated test file"
echo "7. Add existing files from RickTerminalUITests folder to the new target"
echo ""
echo "Alternatively, use the following command to let Xcode detect the new files:"
echo "  open '$PROJECT_DIR/RickTerminal.xcodeproj'"
echo ""
echo "Test files created in: $UITEST_DIR"
echo "  - AppLaunchTests.swift"
echo "  - TerminalInteractionTests.swift"
echo "  - FileBrowserTests.swift"
echo "  - KanbanBoardTests.swift"
echo ""
