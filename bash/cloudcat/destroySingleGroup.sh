#! /bin/bash

source ./loadCredentials.sh

GROUP_ID=$1
SHORT_NAME="$(./singleGroupRawInfo.sh "$GROUP_ID"|jq -r .shortName)"

rm -r ~/.ssh/id_rsa_cloudcat_"$SHORT_NAME"
rm -r ~/.ssh/id_rsa_cloudcat_"$SHORT_NAME".pub

path="$BASE_PATH/destroy/$GROUP_ID?username=$USER_NAME&apiKey=$USER_API_KEY"
curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path" 2>/dev/null