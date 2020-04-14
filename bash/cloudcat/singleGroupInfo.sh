#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/show/$1?username=$USER_NAME&apiKey=$USER_API_KEY"
jsonResponse=$(curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path")

echo "Response JSON: $jsonResponse"

echo ""

printf "Host Name\t\t\t\tIP\n"
echo "------------------------------------------------------"
echo "$jsonResponse"|jq -r '.provisionedInstances[] |[ .hostname, .publicIp] |@tsv'

