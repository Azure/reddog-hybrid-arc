#!/bin/bash

source ./vars.sh

# Delete SSH Keys
rm -rf ssh_keys

# Delete logs
rm -rf logs

# Delete Resource Groups
for branch in $BRANCHES
do
export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-$BRANCH_NAME-$RG_LOCATION

# Create Branch
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait
done