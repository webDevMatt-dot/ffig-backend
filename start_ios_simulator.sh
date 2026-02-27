#!/bin/bash
open -a Simulator
# Check if Simulator is already running
if pgrep -f "Simulator" > /dev/null; then
    echo "Simulator is already running."
else
    echo "Starting Simulator..."
    open -a Simulator
fi

# Wait a bit for Simulator to initialize
sleep 3

# Get the default simulator (first booted)
SIMULATOR_ID=$(xcrun simctl list devices booted --json | jq -r '.devices | to_entries[].value[] | select(.state=="Booted") | .udid' | head -n 1)

if [ -z "$SIMULATOR_ID" ]; then
    echo "No booted simulator found. Looking for an available iPhone simulator..."
    # Find the latest runtime and the first iPhone device
    SIMULATOR_ID=$(xcrun simctl list devices --json | jq -r '.devices | to_entries | map(.value) | flatten | map(select(.name | test("iPhone"))) | .[0].udid')
    
    if [ -n "$SIMULATOR_ID" ] && [ "$SIMULATOR_ID" != "null" ]; then
        echo "Found simulator: $SIMULATOR_ID. Booting..."
        xcrun simctl boot "$SIMULATOR_ID"
        sleep 5
    else
        echo "No iPhone simulators found! Please create one in Xcode."
        exit 1
    fi
fi

echo "Using simulator: $SIMULATOR_ID"

# Run the Flutter app
echo "Building and running Flutter app..."
cd mobile_app && flutter run