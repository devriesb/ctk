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

#ssh-keygen -t rsa -f "$keyFile" -q -P ""
#PUBLIC_KEY=$(cat "$keyFile".pub)



INIT_SCRIPT=$(
  cat <<EOF
$USER_DATA
echo "$CM_6_3_3_BASE_URL" > ~/.base_archive_url

# add sudo user
adduser $USER_NAME
echo "cloudera" | passwd $USER_NAME --stdin
usermod -aG wheel $USER_NAME
mkdir -p /home/$USER_NAME/.ssh
cp /home/root/.ssh/authorized_keys  /home/$USER_NAME/.ssh/authorized_keys
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/
chmod 640 /home/$USER_NAME/.ssh/authorized_keys

create_yum_parcel_repo

EOF
)

BASE64_SCRIPT=$(echo "$INIT_SCRIPT" | base64)

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
  "initScript": "echo \"$BASE64_SCRIPT\" | base64 --decode | bash",
  "primarySize": "cpus_01_ramGB_004",
  "primaryCount": "1",
  "secondaryCount": "0",
  "apiProvision": "TRUE"
}
EOF
)

export POST_DATA

#echo $POST_DATA

#echo "$POST_DATA" | jq -r '.initScript'

#echo "$INIT_SCRIPT"

source ./doCreate.sh

echo "Group ID (from create yum): $NEW_GROUP_ID"
export NEW_GROUP_ID
