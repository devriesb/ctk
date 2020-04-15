#! /bin/bash

source ./loadCredentials.sh

path="$BASE_PATH/filter?\
filter.username=$USER_NAME&\
filter.op.username=Equal&\
filter.provisionStatus=Destroyed&\
filter.op.provisionStatus=NotEqual&\
apiKey=$USER_API_KEY"

jsonResponse=$(curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path" 2>/dev/null)

#echo "Response JSON:"
#echo "$jsonResponse"

echo ""

echo "CM Hosts: "
echo "$jsonResponse" | jq -r '.provisionedInstanceGroupInstanceList[].provisionedInstances[].hostname' | xargs | sed -e 's/ /, /g'
