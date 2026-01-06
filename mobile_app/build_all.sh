#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Starting Full Build Process..."

# Ensure we are in the mobile_app directory for flutter builds
# (Assuming script is run from inside mobile_app or we ensure path)
# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# 1. Build APK
echo "📦 Building Android APK..."
flutter build apk --release
echo "✅ APK Build Complete!"

# 2. Build Web
echo "🌐 Building Web App..."
flutter build web --release
echo "✅ Web Build Complete!"

# 3. Git Operations
echo "⬆️  Pushing to Git..."
# Move to Repo Root (assuming mobile_app is one level deep)
cd ..

git add .
git commit -m "build(release): auto-generated web & apk output" || echo "⚠️  No changes to commit"
git push

echo "🎉 All builds finished and pushed successfully!"
echo "📂 APK: mobile_app/build/app/outputs/flutter-apk/app-release.apk"
echo "📂 Web: mobile_app/build/web/"
