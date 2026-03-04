#!/bin/bash

# Exit on any error
set -e

# Change to the root directory
cd "$(dirname "$0")"

echo "🚀 Starting Shorebird OTA Patch Deployment..."

# Optional: Run tests or formatting here if desired
# echo "🧪 Running tests..."
# cd mobile_app && flutter test && cd ..

# Step 1: Bump version automatically (optional, but good for tracking which patch went where)
echo "📦 Incrementing version number..."
./bump_version.sh

cd mobile_app

# Step 2: Push Android Patch
echo "🤖 Pushing Android patch..."
~/.shorebird/bin/shorebird patch android --allow-asset-diffs --allow-native-diffs

# Step 3: Push iOS Patch
echo "🍏 Pushing iOS patch..."
~/.shorebird/bin/shorebird patch ios --allow-asset-diffs --allow-native-diffs

echo "🎉 OTA Patch Deployment Complete! Users will get the update next time they open the app."
