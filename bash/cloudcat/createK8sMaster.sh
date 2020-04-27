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

keyFile=~/.ssh/id_rsa_cloudcat_"$shortName"

ssh-keygen -t rsa -f "$keyFile" -q -P ""
ssh-add "$keyFile"

PUBLIC_KEY=$(cat "$keyFile".pub)

INIT_SCRIPT=$(
  cat <<EOF
$USER_DATA
echo "$CM_6_3_3_BASE_URL" > ~/.base_archive_url
echo "$PUBLIC_KEY" >>  ~/.ssh/authorized_keys

# add sudo user
adduser $USER_NAME
echo "cloudera" | passwd $USER_NAME --stdin
usermod -aG wheel $USER_NAME
mkdir -p /home/$USER_NAME/.ssh
echo "$PUBLIC_KEY" >>  /home/$USER_NAME/.ssh/authorized_keys
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/
chmod 640 /home/$USER_NAME/.ssh/authorized_keys


wget https://LFtraining:Penguin2014@training.linuxfoundation.org/cm/LFS258/LFS258_V2020-04-20_SOLUTIONS.tar.bz2

tar -xvf LFS258_V2020-04-20_SOLUTIONS.tar.bz2

apt-get update && apt-get upgrade -y

apt-get install -y vim

apt-get install -y docker.io

EOF
)

BASE64_SCRIPT=$(echo "$INIT_SCRIPT" | base64)

POST_DATA=$(
  cat <<EOF
{
  "username": "$USER_NAME",
  "apiKey": "$USER_API_KEY",
  "offset": "0",
  "subDomain": "vpc.cloudera.com",
  "shortName": "$shortName",
  "sendEmail": "FALSE",
  "description": "",
  "cloudType": "4",
  "amiName": "cloudera-systest-base-ubuntu-16.04-hvm",
  "awsRegion": "us-west-2",
  "initScript": "echo \"$BASE64_SCRIPT\" | base64 --decode | bash",
  "primarySize": "m3.xlarge",
  "primaryCount": "1",
  "alternateSize": "t2.nano",
  "secondaryCount": "0"
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
