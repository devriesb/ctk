#! /bin/bash

# export cloudcat credentials
USER_NAME=$(cat ~/.cloudcat/username)
export USER_NAME

USER_API_KEY=$(cat ~/.cloudcat/api-key)
export USER_API_KEY

# get pre-defined cloudcat id_rsa
keyFile=~/.ssh/id_rsa_cloudcat

if [ ! -f "$keyFile" ]; then
  curl https://github.mtv.cloudera.com/raw/QE/deploy/master/cdep/data/id_rsa >~/.ssh/id_rsa_cloudcat
fi
chmod 600 ~/.ssh/id_rsa_cloudcat
ssh-add "$keyFile"

# export constants
export BASE_PATH="https://cloudcat.infra.cloudera.com/api/provisionedInstanceGroup"
export USER_DATA="wget https://raw.githubusercontent.com/devriesb/ctk/master/bash/cm-install.sh && source cm-install.sh"
