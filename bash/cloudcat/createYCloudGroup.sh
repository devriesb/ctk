#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/save"
DATA_PATH="/tmp/data-$(date +%s)-$RANDOM.json"

cat > "$DATA_PATH" << EOF
{
  "username": "$USER_NAME",
  "apiKey": "$USER_API_KEY",
  "offset": "0",
  "subDomain": "root.hwx.site",
  "shortName": "$1",
  "sendEmail": "FALSE",
  "description": "",
  "cloudType": "4",
  "imageName": "registry.eng.hortonworks.com/hortonworks/base-ubuntu16:0.1.0.0-92",
  "ycloudQueue": "default-developers",
  "initScript": "$USER_DATA $2",
  "primarySize": "cpus_01_ramGB_004",
  "primaryCount": "1",
  "secondaryCount": "0",
  "apiProvision": "TRUE"
}
EOF
curl -H "Accept: application/json" \
     -H "Content-type: application/json" \
     -d "@$DATA_PATH" \
     -X POST $path

rm "$DATA_PATH"