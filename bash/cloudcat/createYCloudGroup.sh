#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/save"
DATA_PATH="/tmp/data-$(date +%s)-$RANDOM.json"

SHORT_NAME=$1
INIT_SCRIPT=$2
PRIMARY_COUNT=$3

cat >"$DATA_PATH" <<EOF
{
  "username": "$USER_NAME",
  "apiKey": "$USER_API_KEY",
  "offset": "0",
  "subDomain": "root.hwx.site",
  "shortName": "$SHORT_NAME",
  "sendEmail": "FALSE",
  "description": "",
  "cloudType": "4",
  "imageName": "registry.eng.hortonworks.com/hortonworks/base-centos7.7:0.1.0.0-95",
  "ycloudQueue": "default-developers",
  "initScript": "$USER_DATA && $INIT_SCRIPT",
  "primarySize": "cpus_04_ramGB_016",
  "primaryCount": "${PRIMARY_COUNT:-1}",
  "secondaryCount": "0",
  "apiProvision": "TRUE"
}
EOF
jsonResponse=$(curl -H "Accept: application/json" \
  -H "Content-type: application/json" \
  -d "@$DATA_PATH" \
  -X POST "$path" 2>/dev/null)

echo "Response JSON: $jsonResponse"

echo ""

echo "Group ID: $(echo "$jsonResponse"|jq '.id')"

rm "$DATA_PATH"
