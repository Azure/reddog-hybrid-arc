#! /bin/bash

# Set Variables
export ARM_DEPLOYMENT_NAME="reddoghubbicep"
export SUBSCRIPTION="40545cc3-81f4-42c9-953d-67534438918e"
export TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"
export ADMIN_USER_NAME='raykao'
export SSH_KEY_PATH="./ssh_keys"
export SQL_ADMIN_USER_NAME="reddogadmin"
export SQL_ADMIN_PASSWD="nJ0fqrQx7T^NZFl4sFf*U"

export PREFIX=$(cat infra.json|jq -r '.hub.rgNamePrefix')
export RG_LOCATION=$(cat infra.json|jq -r '.hub.location')
export RG_NAME=reddog-$PREFIX-hub-$RG_LOCATION