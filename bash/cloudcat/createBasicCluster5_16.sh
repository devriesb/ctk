#! /bin/bash

source ./loadCredentials.sh

timestamp=$(date "+%Y-%m-%d-%H-%M-%S")

./createYCloudGroup.sh "$USER_NAME"-agent-"$timestamp" install_cloudera_agent_5_16_1 3
./createYCloudGroup.sh "$USER_NAME"-cm-"$timestamp" install_cloudera_manager_5_16_1 1

./listGroups.sh
./getCmHosts.sh