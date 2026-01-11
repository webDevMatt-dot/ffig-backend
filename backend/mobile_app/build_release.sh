#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 Starting Release Builds..."

# Ensure we are in the mobile_app directory
cd "$SCRIPT_DIR"

echo "🌐 Building Web App (Release)..."
flutter build web --release

echo "📦 Building Android APK (Release)..."
flutter build apk --release

echo "✅ Build Complete!"
