#!/bin/bash

# Exit on error
set -o errexit

echo "🚀 Starting Flutter Web Build on Render..."

# 1. Install Flutter
echo "📥 Downloading Flutter..."
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"

# 2. Verify Install
flutter doctor

# 3. Build Web App
echo "🔨 Building Web App..."
flutter pub get
flutter build web --release --no-tree-shake-icons

echo "✅ Build Complete! Output is in build/web"
