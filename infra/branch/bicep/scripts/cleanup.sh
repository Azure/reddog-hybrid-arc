#!/bin/bash

# Delete SSH Keys
rm -rf ssh_keys

# Delete logs
rm -rf logs

export RG_PREFIX="$(cat infra.json|jq -r '.rgPrefix')"

# Delete Resource Groups
for branch in $(cat infra.json|jq -c '.branches[]')
do
export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$RG_PREFIX-$BRANCH_NAME-$RG_LOCATION

# Create Branch
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait
done