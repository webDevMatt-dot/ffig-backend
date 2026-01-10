#!/bin/bash

# Configuration
API_URL="https://ffig-backend-ti5w.onrender.com/api/home/version/"
# TOKEN="" # You need an Admin Token here. Ideally fetched via login.

echo "🚀 Auto-Updating Backend Version..."

# 1. Extract Version from pubspec.yaml
VERSION=$(grep 'version:' mobile_app/pubspec.yaml | sed 's/version: //')
# Remove build number (everything after +)
CLEAN_VERSION="${VERSION%+*}"

echo "Detected Version: $CLEAN_VERSION"

# 1.5 Ensure Admin User Exists (Critical for Ephemeral/Fresh DBS)
# Note: We can only run this if we have shell access, which we don't from here easily unless we ssh or run it as a build step.
# Ideally, this should be part of the Render 'Build Command' or 'Start Command'.
# However, if we are just hitting the API, we assume the server is up and might be fresh.
# If fresh, we can't login!
# OPTION: We can't really fix a fresh DB from *here* (client side script).
# The BACKEND itself needs to create the user on startup/migrate.

# But for now, we will proceed.


# 2. Get Admin Token (One-off login for script)
USERNAME="${FFIG_ADMIN_USERNAME:-admin}"
PASSWORD="${FFIG_ADMIN_PASSWORD:-ChangeMe123!}"

if [ "$USERNAME" == "admin" ] && [ "$PASSWORD" == "ChangeMe123!" ]; then
    echo "⚠️  Using default credentials. Ensure FFIG_ADMIN_USERNAME and FFIG_ADMIN_PASSWORD are set in CI."
fi

LOGIN_RESPONSE=$(curl -s -X POST https://ffig-backend-ti5w.onrender.com/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"access":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to login to update version."
  echo "Server Response: $LOGIN_RESPONSE"
  exit 1
fi

echo "✅ Authenticated."

# 3. Post New Version
echo "📡 Sending Version Update to Backend..."

RESPONSE=$(curl -s -X POST $API_URL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"platform\": \"ANDROID\",
    \"latest_version\": \"$CLEAN_VERSION\",
    \"update_url\": \"https://ffig-mobile-n999.onrender.com/app.apk\",
    \"required\": false
  }")

# Also update iOS just in case
RESPONSE_IOS=$(curl -s -X POST $API_URL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"platform\": \"IOS\",
    \"latest_version\": \"$CLEAN_VERSION\",
    \"update_url\": \"https://ffig-mobile-n999.onrender.com/app.apk\",
    \"required\": false
  }")

echo "✅ Backend Version Updated: $CLEAN_VERSION"
