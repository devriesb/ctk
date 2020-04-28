#! /bin/bash

source ./loadCredentials.sh

echo "NEW_GROUP_ID: $NEW_GROUP_ID"
echo""

path="$BASE_PATH/show/${1:-$NEW_GROUP_ID}?username=$USER_NAME&apiKey=$USER_API_KEY"
jsonResponse=$(curl -H "Accept: application/json" -H "Content-type: application/json" -X GET "$path" 2>/dev/null)

(printf "HOST_NAME\tSTATUS\tIP\n"; \
echo -e "---------\t------\t--\n"; \
echo "$jsonResponse"|jq -r '.provisionedInstances[] |[ .hostname, .provisionStatusString, .publicIp] |@tsv' \
) | column -ts $'\t'

