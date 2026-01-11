#!/bin/bash
API_URL="https://ffig-backend-ti5w.onrender.com/api"
USERNAME="${FFIG_ADMIN_USERNAME:-admin}"
PASSWORD="${FFIG_ADMIN_PASSWORD:-ChangeMe123!}"

echo "1. Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST $API_URL/auth/login/ \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"access":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Login Failed: $LOGIN_RESPONSE"
  exit 1
fi
echo "✅ Logged in. Token acquired."

echo "2. Hitting Community Chat Endpoint..."
CHAT_RESPONSE=$(curl -s -X GET $API_URL/chat/community/ \
  -H "Authorization: Bearer $TOKEN")

echo "Chat Response: $CHAT_RESPONSE"
CONVO_ID=$(echo $CHAT_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)

echo "3. Sending Test Message to ID: $CONVO_ID..."
SEND_RESPONSE=$(curl -s -X POST $API_URL/chat/messages/send/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"conversation_id\": $CONVO_ID, \"text\": \"Hello from automated test!\"}")

echo "4. verify messages..."
GET_MSG_RESPONSE=$(curl -s -X GET $API_URL/chat/conversations/$CONVO_ID/messages/ \
  -H "Authorization: Bearer $TOKEN")

echo "Messages: $GET_MSG_RESPONSE"
