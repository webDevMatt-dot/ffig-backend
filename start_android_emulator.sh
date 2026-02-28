#!/bin/bash

# Configuration
EMULATOR_PATH="$HOME/Library/Android/sdk/emulator/emulator"
ADB_EXE="$HOME/Library/Android/sdk/platform-tools/adb"
AVD_NAME="Pixel_8a"

# Fallback if Pixel_8a is not found (use the first available)
if ! "$EMULATOR_PATH" -list-avds | grep -q "$AVD_NAME"; then
    AVD_NAME=$("$EMULATOR_PATH" -list-avds | head -n 1)
fi

if [ -z "$AVD_NAME" ]; then
    echo "No Android AVDs found! Please create one in Android Studio."
    exit 1
fi

# Check if emulator is already running
if "$ADB_EXE" devices | grep -q "emulator"; then
    echo "Android emulator is already running."
else
    echo "Starting Android emulator ($AVD_NAME)..."
    # Start emulator in background with no snapshot for clean boot
    "$EMULATOR_PATH" -avd "$AVD_NAME" -no-snapshot-load > /dev/null 2>&1 &
    
    # Wait for emulator to be detected by adb
    echo "Waiting for Android emulator to boot..."
    while ! "$ADB_EXE" devices | grep -q "emulator"; do
        sleep 2
    done
fi

echo "Android emulator is ready."
