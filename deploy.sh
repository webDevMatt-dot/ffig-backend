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

# --- Multi-platform Builds ---
echo "🚀 STARTING BUILDS..."
cd mobile_app

echo "📦 Syncing dependencies..."
flutter pub get

echo "🏗️  Step 1: Building Android (App Bundle)..."
flutter build appbundle --release

echo "🏗️  Step 2: Building iOS (Release - No Codesign)..."
flutter build ios --release --no-codesign

echo "🏗️  Step 3: Building Web..."
flutter build web --release --no-tree-shake-icons

cd ..

if [ -f "auto_update_version.sh" ]; then
  echo "🔄 Updating server version..."
  chmod +x auto_update_version.sh
  ./auto_update_version.sh
fi

echo "🎉 DEPLOYMENT COMPLETE"