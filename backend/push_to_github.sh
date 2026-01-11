#!/bin/bash
set -e

# Get the directory where this script is located (repo root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 Starting Git Push Process..."

# --- 1. Push mobile_app (Nested Repo) ---
echo "📂 Entering mobile_app directory..."
cd mobile_app

echo "📁 Staging mobile_app files..."
git add .

echo "💾 Committing mobile_app..."
git commit -m "build(release): web and apk update" || echo "⚠️  No changes to commit in mobile_app"

echo "⬆️  Pushing mobile_app to remote..."
git push

# --- 2. Push Root Repo (ffig-mobile-app) ---
echo "📂 Returning to root directory..."
cd ..

echo "📁 Staging root files..."
git add .

echo "💾 Committing root..."
git commit -m "build(release): web and apk update" || echo "⚠️  No changes to commit in root"

echo "⬆️  Pushing root to remote..."
git push

echo "🎉 SUCCESS: Code pushed to GitHub!"

# --- 3. Auto-Version Update ---
echo "🔄 Checking for Version Update..."
if [ -f "auto_update_version.sh" ]; then
    chmod +x auto_update_version.sh
    ./auto_update_version.sh
else
    echo "⚠️  auto_update_version.sh not found. Skipping backend update."
fi
