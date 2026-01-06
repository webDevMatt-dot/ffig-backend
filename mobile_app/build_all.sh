#!/bin/bash
set -e

# Increase Git Buffer size to handle large pushes (fixes HTTP 400 error)
git config http.postBuffer 524288000

# Get the directory where this script is located (mobile_app)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 Starting Build & Push Process..."

# --- 1. Flutter Builds (must be in mobile_app folder) ---
cd "$SCRIPT_DIR"

echo "📦 Building Android APK..."
flutter build apk --release

echo "🌐 Building Web App..."
flutter build web --release

# --- 2. Git Operations (must be in repo root) ---
cd .. # Move up to ffig-mobile-app

echo "submit: Staging all files..."
git add .

echo "submit: Committing..."
# Allow empty message check: if commit fails (no changes), script continues due to || true
git commit -m "build(release): web and apk update" || echo "⚠️  No changes to commit"

echo "submit: Pushing to remote..."
git push

echo "🎉 SUCCESS: App built and pushed to repo!"
