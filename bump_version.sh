#!/bin/bash
set -e

PUBSPEC="mobile_app/pubspec.yaml"

echo "🔄 Bumping Version in $PUBSPEC..."

# Extract current version line. Example: version: 1.0.17+17
VERSION_LINE=$(grep "^version: " $PUBSPEC)
# Extract version string: 1.0.17+17
CURRENT_VERSION=$(echo $VERSION_LINE | sed 's/version: //')

# Split into X.Y.Z and Build Number
BASE_VERSION=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Split BASE_VERSION into Major, Minor, Patch
MAJOR=$(echo $BASE_VERSION | cut -d'.' -f1)
MINOR=$(echo $BASE_VERSION | cut -d'.' -f2)
PATCH=$(echo $BASE_VERSION | cut -d'.' -f3)

# Increment Patch and Build Number
NEW_PATCH=$((PATCH + 1))
NEW_BUILD=$((BUILD_NUMBER + 1))

NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH+$NEW_BUILD"

echo "   Current: $CURRENT_VERSION"
echo "   New:     $NEW_VERSION"

# Use python to replace simply and safely (sed varies across MacOS/Linux)
# Or use perl. Mac has perl installed by default.
perl -pi -e "s/version: .*/version: $NEW_VERSION/" $PUBSPEC

echo "✅ Version updated to $NEW_VERSION"
