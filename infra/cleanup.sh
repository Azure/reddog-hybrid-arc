#!/bin/bash

source ./var.sh cleanup

# Delete SSH Keys
rm -rf $SSH_KEY_PATH

# Delete logs
rm -rf logs

# Delete outputs
rm -rf outputs

# Delete Hub Resource Group
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait

# Delete Branch Resource Groups
for branch in $BRANCHES
do
export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-reddog-$BRANCH_NAME-$RG_LOCATION

# Create Branch
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait
done