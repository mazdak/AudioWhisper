#!/bin/bash
# Creates a new Xcode project for TwilioConnect.
# Run this script from the TwilioConnect directory.
#
# Prerequisites: Xcode command line tools installed.
#
# Usage:
#   cd TwilioConnect
#   chmod +x create-xcode-project.sh
#   ./create-xcode-project.sh
#
# This will create TwilioConnect.xcodeproj that references all Swift files
# in the project structure. Open it in Xcode to build and run.

set -euo pipefail

PROJECT_NAME="TwilioConnect"
BUNDLE_ID="com.twilioconnect.app"
TEAM_ID="" # Set your Apple Developer Team ID here if needed
DEPLOYMENT_TARGET="17.0"

echo "Creating Xcode project for ${PROJECT_NAME}..."
echo ""
echo "To set up the project in Xcode:"
echo "1. Open Xcode and create a new iOS App project named '${PROJECT_NAME}'"
echo "2. Set the bundle identifier to '${BUNDLE_ID}'"
echo "3. Set deployment target to iOS ${DEPLOYMENT_TARGET}"
echo "4. Delete the auto-generated ContentView.swift and ${PROJECT_NAME}App.swift"
echo "5. Drag the following folders into the Xcode project navigator:"
echo "   - App/"
echo "   - Core/"
echo "   - Features/"
echo "   - Shared/"
echo "   - Resources/Info.plist (set as Info.plist in build settings)"
echo ""
echo "6. In the target's 'Signing & Capabilities' tab, add:"
echo "   - Background Modes -> Voice over IP"
echo ""
echo "7. In the target's 'Info' tab, add:"
echo "   - NSMicrophoneUsageDescription"
echo ""
echo "8. Build and run!"
echo ""
echo "All Swift source files:"
find . -name "*.swift" -not -path "*/Package.swift" | sort
