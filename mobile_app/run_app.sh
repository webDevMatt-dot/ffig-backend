#!/bin/bash

echo "🔌 Starting ADB..."
adb start-server

echo "📱 Checking connected devices..."
adb devices

echo "🧹 Removing old app (if exists)..."
adb uninstall com.ffiglobal.mobile_app >/dev/null 2>&1

echo "🛠 Cleaning build..."
flutter clean

echo "📦 Getting packages..."
flutter pub get

echo "🚀 Running app..."
flutter run

