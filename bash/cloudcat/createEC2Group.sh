#! /bin/bash

source ./loadCredentials.sh

timestamp=$(date "+%Y-%m-%d-%H-%M-%S")

SHORT_NAME=${1:-$USER_NAME-$timestamp}
PRIMARY_COUNT=${2:-1}

POST_DATA=$(
  cat <<EOF
{
  "username": "$USER_NAME",
  "apiKey": "$USER_API_KEY",
  "offset": "0",
  "subDomain": "vpc.cloudera.com",
  "shortName": "$SHORT_NAME",
  "sendEmail": "FALSE",
  "description": "my api test instance",
  "cloudType": "1",
  "amiName": "cloudera-systest-base-ubuntu-16.04-hvm",
  "awsRegion": "us-west-2",
  "initScript": "echo /etc/*release",
  "primarySize": "t2.nano",
  "primaryCount": "$PRIMARY_COUNT",
  "alternateSize": "t2.nano",
  "secondaryCount": "0"
}
EOF
)

export POST_DATA

source ./doCreate.sh
