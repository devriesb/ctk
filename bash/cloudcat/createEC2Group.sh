#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/save"
DATA_PATH="/tmp/data-$(date +%s)-$RANDOM.json"

cat > "$DATA_PATH" << EOF
{
  "username": "$USER_NAME",
  "apiKey": "$USER_API_KEY",
  "offset": "0",
  "subDomain": "vpc.cloudera.com",
  "shortName": "$1",
  "sendEmail": "FALSE",
  "description": "my api test instance",
  "cloudType": "1",
  "amiName": "cloudera-systest-base-ubuntu-16.04-hvm",
  "awsRegion": "us-west-2",
  "initScript": "echo /etc/*release",
  "primarySize": "t2.nano",
  "primaryCount": "1",
  "alternateSize": "t2.nano",
  "secondaryCount": "0"
}
EOF
curl -H "Accept: application/json" \
     -H "Content-type: application/json" \
     -d "@$DATA_PATH" \
     -X POST "$path" 2>/dev/null

rm "$DATA_PATH"