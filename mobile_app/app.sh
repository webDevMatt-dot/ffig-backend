#!/bin/bash
# run_app.sh
# Usage: ./run_app.sh

# Kill and restart ADB server
adb kill-server
adb start-server

echo "Removing old app (if exists)..."
adb uninstall com.ffiglobal.mobile_app || echo "No previous install or timed out"

# List connected devices
echo "Devices connected:"
adb devices

# Uninstall previous version of the app
echo "Uninstalling old version..."
adb uninstall com.ffiglobal.mobile_app || echo "No previous install found"

# Run Flutter app
echo "Running Flutter app..."
flutter clean
flutter pub get
flutter run --no-tree-shake-icons


