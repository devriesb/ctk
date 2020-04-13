#! /bin/bash

USER_NAME=$(cat ~/.cloudcat/username)
export USER_NAME

USER_API_KEY=$(cat ~/.cloudcat/api-key)
export USER_API_KEY

export BASE_PATH="https://cloudcat.infra.cloudera.com/api/provisionedInstanceGroup"

export USER_DATA="wget https://raw.githubusercontent.com/devriesb/ctk/master/bash/cm-install.sh && source cm-install.sh &&"
