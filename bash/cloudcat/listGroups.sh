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

date
echo ""

(printf "Group Name\tStatus\tID\n"; \
echo -e "-----------\t-------\t---"; \
echo "$jsonResponse"|jq -r '.provisionedInstanceGroupInstanceList[] | [.shortName, .provisionStatusString, .id] |@tsv' \
) | sort | column -ts $'\t'

echo ""

(printf "HOST_NAME\tSTATUS\tIP\n"; \
echo -e "----------\t------\t--\n"; \
echo "$jsonResponse"|jq -r '.provisionedInstanceGroupInstanceList[].provisionedInstances[] |[ .hostname, .provisionStatusString, .publicIp] |@tsv' \
) | sort | column -ts $'\t'