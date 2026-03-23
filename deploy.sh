#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 STARTING FULL DEPLOYMENT..."

command -v flutter >/dev/null || { echo "❌ Flutter not installed"; exit 1; }
command -v git >/dev/null || { echo "❌ Git not installed"; exit 1; }

COMMIT_MSG="${1:-build(release): system update}"

# --- Git Push Frontend ---
echo "📂 Entering mobile_app (Frontend Repository)..."
cd mobile_app
echo "✨ Pushing Frontend changes..."
git add .
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
  echo "🛡️  Syncing with remote..."
  git pull --rebase origin main
  git push origin main
else
  echo "⚠️  No frontend changes to push."
fi
cd ..

# --- Git Push Backend (Root) ---
echo "📂 Pushing Backend/Root changes..."
git add .
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
  echo "🛡️  Syncing with remote..."
  git pull --rebase origin main
  git push origin main
else
  echo "⚠️  No backend changes to push."
fi

# --- Bump Version ---
echo "🔢 Bumping version..."
cd mobile_app
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')
# e.g. 1.0.297+297
SEMVER="${CURRENT_VERSION%+*}"        # 1.0.297
BUILD="${CURRENT_VERSION##*+}"        # 297
PREFIX="${SEMVER%.*}"                 # 1.0
NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${PREFIX}.${NEW_BUILD}+${NEW_BUILD}"
sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
echo "✅ Version bumped: ${CURRENT_VERSION} → ${NEW_VERSION}"

# Commit the version bump
git add pubspec.yaml
git commit -m "chore: bump version to ${NEW_VERSION}"
echo "🛡️  Syncing with remote..."
git pull --rebase origin main
git push origin main
cd ..

# --- Multi-platform Builds ---
echo "🚀 STARTING BUILDS..."
cd mobile_app

echo "📦 Syncing dependencies..."
flutter pub get

echo "🍏 Syncing iOS Pods (Required to sync version bump to Xcode)..."
cd ios && pod install && cd ..

echo "🏗️  Step 1: Building Android (App Bundle & APK)..."
flutter build appbundle --release
flutter build apk --release

echo "🏗️  Step 2: Building iOS Archive (for App Store Connect)..."
# Flutter builds the framework first
flutter build ios --release --no-codesign
# xcodebuild physically creates the App Store archive in Xcode Organizer
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -allowProvisioningUpdates archive || echo "⚠️ iOS Archive failed. Please archive manually in Xcode."

#echo "🏗️  Step 3: Building Web..."
#flutter build web --release --no-tree-shake-icons

cd ..

if [ -f "auto_update_version.sh" ]; then
  echo "🔄 Updating server version..."
  chmod +x auto_update_version.sh
  ./auto_update_version.sh
fi

echo "🎉 DEPLOYMENT COMPLETE"