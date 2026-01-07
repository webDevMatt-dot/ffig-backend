#!/bin/bash
set -e

# Get the directory where this script is located (repo root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 Starting Git Push Process..."

# Ensure we are in the root directory
cd "$SCRIPT_DIR"

# Increase Git Buffer size to handle large pushes (optional but helpful)
git config http.postBuffer 524288000

echo "📁 Staging all files..."
git add .

echo "💾 Committing..."
# Allow empty message check: if commit fails (no changes), script continues due to || true
git commit -m "build(release): web and apk update" || echo "⚠️  No changes to commit"

echo "⬆️  Pushing to remote..."
git push

echo "🎉 SUCCESS: Code pushed to GitHub!"
