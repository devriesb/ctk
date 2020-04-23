#! /bin/bash

source ./loadCredentials.sh

timestamp=$(date "+%Y-%m-%d-%H-%M-%S")

./createYCloudGroup.sh "$USER_NAME"-agent-"$timestamp" install_cloudera_agent_6 3
./createYCloudGroup.sh "$USER_NAME"-cm-"$timestamp" install_cloudera_manager_6 1

./listGroups.sh
./getCmHosts.sh