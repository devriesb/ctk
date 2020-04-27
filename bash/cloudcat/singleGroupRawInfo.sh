#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/show/$1?username=$USER_NAME&apiKey=$USER_API_KEY"
jsonResponse=$(curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path" 2>/dev/null)

echo "$jsonResponse"
