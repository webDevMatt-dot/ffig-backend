#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
# We need to find the Flutter project root (where pubspec.yaml is).
# Since this script is in ios/ci_scripts, the root is usually two levels up.
cd ../.. 

# If pubspec.yaml is not here, try to find it.
if [ ! -f "pubspec.yaml" ]; then
    echo "Searching for pubspec.yaml..."
    FLUTTER_ROOT_DIR=$(find . -name "pubspec.yaml" -maxdepth 2 -exec dirname {} \;)
    if [ -n "$FLUTTER_ROOT_DIR" ]; then
        cd "$FLUTTER_ROOT_DIR"
    else
        echo "Error: Could not find pubspec.yaml"
        exit 1
    fi
fi

echo "Flutter project root: $(pwd)"

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Precache and get dependencies.
flutter precache --ios
flutter pub get

# Install CocoaPods dependencies.
if [ -d "ios" ]; then
    cd ios
fi
pod install

exit 0
