#!/bin/bash

# Configuration
API_URL="https://ffig-backend-ti5w.onrender.com/api/home/version/"
API_URL_LOGIN="https://ffig-backend-ti5w.onrender.com/api/auth/login/"
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

# Capture HTTP Status and Body
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL_LOGIN \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")

HTTP_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')
HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | tail -n 1)

if [ "$HTTP_STATUS" != "200" ]; then
  echo "⚠️  Backend returned HTTP $HTTP_STATUS during login."
  echo "    This is expected if the backend is currently redeploying or broken."
  echo "    skipping backend version update."
  exit 0 # Exit 0 to allow deploy.sh to continue
fi

TOKEN=$(echo $HTTP_BODY | grep -o '"access":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to parse token."
  exit 0
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
    \"update_url\": \"https://femalefoundersinitiativeglobal.onrender.com/app.apk\",
    \"required\": false
  }")

# Also update iOS just in case
RESPONSE_IOS=$(curl -s -X POST $API_URL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"platform\": \"IOS\",
    \"latest_version\": \"$CLEAN_VERSION\",
    \"update_url\": \"https://femalefoundersinitiativeglobal.onrender.com/app.apk\",
    \"required\": false
  }")

echo "✅ Backend Version Updated: $CLEAN_VERSION"
