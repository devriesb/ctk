#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/filter?\
filter.username=$USER_NAME&\
filter.op.username=Equal&\
filter.provisionStatus=Destroyed&\
filter.op.provisionStatus=NotEqual&\
apiKey=$USER_API_KEY"

jsonResponse=$(curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path")

echo "Response JSON:"
echo "$jsonResponse"

echo ""

echo "Group IDs: "
echo "$jsonResponse"|jq '.provisionedInstanceGroupInstanceList[].id'