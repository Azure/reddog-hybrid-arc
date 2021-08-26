#! /bin/bash

# Set Variables
export ARM_DEPLOYMENT_NAME="reddoghubbicep"
export SUBSCRIPTION="40545cc3-81f4-42c9-953d-67534438918e"
export TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"

export PREFIX=$(cat infra.json|jq -r '.rgNamePrefix')

export ADMIN_USER_NAME='raykao'
export SSH_KEY_PATH="./ssh_keys"
export SSH_KEY_NAME=$PREFIX"_id_rsa"

export SQL_ADMIN_USER_NAME="reddogadmin"
export SQL_ADMIN_PASSWD="nJ0fqrQx7T^NZFl4sFf*U"

export HUBNAME=$(cat infra.json|jq -r '.hub.hubName')

export RG_LOCATION=$(cat infra.json|jq -r '.hub.location')
export RG_NAME=reddog-$PREFIX-$HUBNAME-$RG_LOCATION

#Generate ssh-key pair
echo "Creating ssh key directory..."
mkdir $SSH_KEY_PATH

echo "Generating ssh key..."
ssh-keygen -f $SSH_KEY_PATH/$SSH_KEY_NAME -N ''
chmod 400 $SSH_KEY_PATH/$SSH_KEY_NAME
export SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME)"
export SSH_PUB_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME.pub)"

# Get the current user Object ID
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)

# Set the Subscriptoin
az account set --subscription $SUBSCRIPTION_ID

