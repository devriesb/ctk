#! /bin/bash

source ./loadCredentials.sh

jsonResponse=$(curl -H "Accept: application/json" \
  -H "Content-type: application/json" \
  -d "$POST_DATA" \
  -X POST "$BASE_PATH/save" 2>/dev/null)

echo "Response JSON: $jsonResponse"

echo ""

NEW_GROUP_ID=$(echo "$jsonResponse" | jq '.id')
echo "Group ID: $NEW_GROUP_ID"
export NEW_GROUP_ID