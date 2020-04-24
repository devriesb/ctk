#! /bin/bash

source ./loadCredentials.sh

### LOAD CLOUDERA ARCHIVE CREDENTIALS ###
CLOUDERA_ARCHIVE_USER_NAME=$(cat ~/.cloudera-archive-credentials/username)
export CLOUDERA_ARCHIVE_USER_NAME

CLOUDERA_ARCHIVE_PASSWORD=$(cat ~/.cloudera-archive-credentials/password)
export CLOUDERA_ARCHIVE_PASSWORD

export CM_6_3_3_BASE_URL="https://$CLOUDERA_ARCHIVE_USER_NAME:$CLOUDERA_ARCHIVE_PASSWORD@archive.cloudera.com/p/"

timestamp=$(date "+%Y-%m-%d-%H-%M-%S")
shortName=$USER_NAME-yum-$timestamp

keyFile=~/.ssh/id_rsa_"$shortName"

ssh-keygen -t rsa -f "$keyFile" -q -P ""
ssh-add "$keyFile"

PUBLIC_KEY=$(cat "$keyFile".pub)

echo "$PUBLIC_KEY"

POST_DATA=$(
  cat <<EOF
{
  "username": "$USER_NAME",
  "apiKey": "$USER_API_KEY",
  "offset": "0",
  "subDomain": "root.hwx.site",
  "shortName": "$shortName",
  "sendEmail": "FALSE",
  "description": "",
  "cloudType": "4",
  "imageName": "registry.eng.hortonworks.com/hortonworks/base-centos7.7:0.1.0.0-95",
  "ycloudQueue": "default-developers",
  "initScript": "$USER_DATA && echo \"$CM_6_3_3_BASE_URL\" > ~/.base_archive_url && echo \"$PUBLIC_KEY\" >>  ~/.ssh/authorized_keys && create_yum_parcel_repo",
  "primarySize": "cpus_01_ramGB_004",
  "primaryCount": "1",
  "secondaryCount": "0",
  "apiProvision": "TRUE"
}
EOF
)

export POST_DATA

./doCreate.sh
