#!/bin/bash
set -e

# Get the directory where this script is located (repo root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 STARTING FULL DEPLOYMENT: BUILD & PUSH..."

# --- 0. Bump Version ---
if [ -f "./bump_version.sh" ]; then
    chmod +x ./bump_version.sh
    ./bump_version.sh
else
    echo "⚠️  bump_version.sh not found. Skipping version bump."
fi

# --- 1. Build & Push mobile_app ---
echo "📂 Entering mobile_app directory..."
cd mobile_app

echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

echo "🔨 Building Web App (Release)..."
flutter build web --release

echo "📦 Building Android APK (Release)..."
flutter build apk --release

echo "📂 Copying APK to Web Source Directory..."
# Extract Version from pubspec.yaml
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
CLEAN_VERSION="${VERSION%+*}"
echo "   Detected Version: $CLEAN_VERSION"

cp build/app/outputs/flutter-apk/app-release.apk web/app.apk
cp build/app/outputs/flutter-apk/app-release.apk "web/app-v$CLEAN_VERSION.apk"

echo "📁 Staging mobile_app files..."
git add .

echo "💾 Committing mobile_app..."
# Allow optional commit message argument, default to "build(release): web and apk update"
COMMIT_MSG="${1:-build(release): web and apk update}"
git commit -m "$COMMIT_MSG" || echo "⚠️  No changes to commit in mobile_app"

echo "⬆️  Pushing mobile_app to remote..."
git push

# --- 2. Push Root Repo ---
echo "📂 Returning to root directory..."
cd ..

echo "📁 Staging root files..."
git add .

echo "💾 Committing root..."
git commit -m "$COMMIT_MSG" || echo "⚠️  No changes to commit in root"

echo "⬆️  Pushing root to remote..."
git push

echo "🎉 SUCCESS: Code built and pushed!"

# --- 3. Version Update ---
echo "🔄 Checking for Version Update..."
if [ -f "auto_update_version.sh" ]; then
    chmod +x auto_update_version.sh
    ./auto_update_version.sh
else
    echo "⚠️  auto_update_version.sh not found. Skipping backend update."
fi
