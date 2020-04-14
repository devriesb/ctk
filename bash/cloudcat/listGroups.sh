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

echo "Groups: "
printf "Short Name\tID\n"
echo "-----------------------"
echo "$jsonResponse"|jq -r '.provisionedInstanceGroupInstanceList[] | [.shortName, .id] |@tsv'

echo ""

echo "Instances: "
printf "Host Name\t\t\t\tIP\n"
echo "------------------------------------------------------"
echo "$jsonResponse"|jq -r '.provisionedInstanceGroupInstanceList[].provisionedInstances[] | [.hostname, .publicIp] | @tsv'