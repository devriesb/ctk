#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/destroy/$1?\
username=$USER_NAME&apiKey=$USER_API_KEY"
curl -H "Accept: application/json" -H "Content-type: application/json" -X GET $path