#!/bin/bash

source ./var.sh

# Delete SSH Keys
rm -rf $SSH_KEY_PATH

# Delete logs
rm -rf logs

# Delete Hub Resource Group
az group delete -n $RG_NAME -y --no-wait

# Delete Branch Resource Groups
for branch in $BRANCHES
do
export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-$BRANCH_NAME-$RG_LOCATION

# Create Branch
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait
done