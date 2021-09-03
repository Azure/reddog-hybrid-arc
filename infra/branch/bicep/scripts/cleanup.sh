#!/bin/bash

source ./var.sh

# Delete SSH Keys
rm -rf ssh_keys

# Delete logs
rm -rf logs

# Delete outputs
rm -rf outputs


# Delete Resource Groups
for branch in $BRANCHES
do
export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-reddog-$BRANCH_NAME-$RG_LOCATION

# Delete AKV SP
SP_APPID=$(az ad sp list --display-name "http://sp-reddog-$PREFIX$BRANCH_NAME.microsoft.com" | jq -r .[].appId)
az ad sp delete --id $SP_APPID || true

# Delete Branch
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait
done