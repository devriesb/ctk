#! /bin/bash

source ./loadCredentials.sh

### LOAD CLOUDERA ARCHIVE CREDENTIALS ###
CLOUDERA_ARCHIVE_USER_NAME=$(cat ~/.cloudera-archive-credentials/username)
export CLOUDERA_ARCHIVE_USER_NAME

CLOUDERA_ARCHIVE_PASSWORD=$(cat ~/.cloudera-archive-credentials/password)
export CLOUDERA_ARCHIVE_PASSWORD

export CM_6_3_3_BASE_URL="https://$CLOUDERA_ARCHIVE_USER_NAME:$CLOUDERA_ARCHIVE_PASSWORD@archive.cloudera.com/p/"

timestamp=$(date "+%Y-%m-%d-%H-%M-%S")
#shortName=$USER_NAME-k8s-$timestamp
shortName=$USER_NAME-k8s-${1:-master}

INIT_SCRIPT=$(
  cat <<EOF
$USER_DATA


# add sudo user
adduser --disabled-password --gecos "" $USER_NAME
usermod -aG sudo bdevries

# update & upgrade
apt-get update
#UCF_FORCE_CONFOLD=1 DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical sudo apt-get -qq -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade


# install packages
apt-get install -y docker.io
echo "deb  http://apt.kubernetes.io/  kubernetes-xenial  main" > /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get update
apt-get install -y kubeadm=1.18.1-00 kubelet=1.18.1-00 kubectl=1.18.1-00 --allow-downgrades
apt-mark hold kubelet kubeadm kubectl
apt-get install -y strace

# get calico yaml
wget https://docs.projectcalico.org/manifests/calico.yaml
cp calico.yaml /home/$USER_NAME


# bash completion
apt-get install bash-completion -y
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(kubectl completion bash)" >> /home/$USER_NAME/.bashrc

# get course material
wget https://LFtraining:Penguin2014@training.linuxfoundation.org/cm/LFS258/LFS258_V2020-04-20_SOLUTIONS.tar.bz2
tar -xvf LFS258_V2020-04-20_SOLUTIONS.tar.bz2



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
  "cloudType": "1",
  "amiName": "cloudera-systest-base-ubuntu-18.04-hvm",
  "awsRegion": "us-east-1",
  "initScript": "echo \"$BASE64_SCRIPT\" | base64 --decode | bash",
  "primarySize": "m4.xlarge",
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
