#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/show/$1?username=$USER_NAME&apiKey=$USER_API_KEY"
jsonResponse=$(curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path")

echo "Response JSON: $jsonResponse"

echo ""

echo "Public IPs:"
echo "$jsonResponse"|jq '.provisionedInstances[].publicIp'

echo "Host Names:"
echo "$jsonResponse"|jq '.provisionedInstances[].hostname'

