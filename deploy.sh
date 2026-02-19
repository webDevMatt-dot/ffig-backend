#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 STARTING FULL DEPLOYMENT..."

command -v flutter >/dev/null || { echo "Flutter not installed"; exit 1; }
command -v git >/dev/null || { echo "Git not installed"; exit 1; }

COMMIT_MSG="${1:-build(release): web update}"

# --- Version bump ---
if [ -f "./bump_version.sh" ]; then
  chmod +x ./bump_version.sh
  ./bump_version.sh
fi

echo "📂 Entering mobile_app..."
cd mobile_app

flutter pub get

if git diff --quiet HEAD -- lib web pubspec.yaml; then
  echo "⚡ No Flutter changes detected. Skipping build."
else
  echo "� Building release apps..."
  flutter build appbundle
  flutter build web --release --no-tree-shake-icons
fi

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
CLEAN_VERSION="${VERSION%%+*}"
echo "Version: $CLEAN_VERSION"

echo "� Committing mobile_app..."
git add .

if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
  git push
else
  echo "⚠️ Nothing to commit"
fi

cd ..

echo "📁 Committing root..."
git add .

if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
  git push
else
  echo "⚠️ Nothing to commit"
fi

if [ -f "auto_update_version.sh" ]; then
  chmod +x auto_update_version.sh
  ./auto_update_version.sh
fi

echo "🎉 DEPLOYMENT COMPLETE"