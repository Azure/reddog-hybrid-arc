#!/bin/bash

# Set Variables from var.sh
source ./var.sh

# Show Params
echo "Parameters"
echo "------------------------------------------------"
echo "ARM_DEPLOYMENT_NAME: $ARM_DEPLOYMENT_NAME"
echo "SUBSCRIPTION: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"
echo "ADMIN_USER_NAME: $ADMIN_USER_NAME"
echo "SSH_KEY_PATH: $SSH_KEY_PATH"
echo "SQL_ADMIN_USER_NAME: $SQL_ADMIN_USER_NAME"
echo "SQL_ADMIN_PASSWD: $SQL_ADMIN_PASSWD"
echo "------------------------------------------------"

#Generate ssh-key pair
echo "Creating ssh key directory..."
mkdir $SSH_KEY_PATH

echo "Generating ssh key..."
ssh-keygen -f $SSH_KEY_PATH/id_rsa -N ''
chmod 400 $SSH_KEY_PATH/id_rsa
export SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/id_rsa)"
export SSH_PUB_KEY="$(cat $SSH_KEY_PATH/id_rsa.pub)"

export PREFIX=$(cat infra.json|jq -r '.hub.rgNamePrefix')
export RG_LOCATION=$(cat infra.json|jq -r '.hub.location')
export RG_NAME=reddog-$PREFIX-hub-$RG_LOCATION

# Get the current user Object ID
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)

# Set the Subscriptoin
az account set --subscription $SUBSCRIPTION_ID

# Create the Resource Group to deploy the Webinar Environment
az group create --name $RG_NAME --location $RG_LOCATION

echo "Deploying hub resources...."
az deployment group create \
  --name $ARM_DEPLOYMENT_NAME \
  --mode Incremental \
  --resource-group $RG_NAME \
  --template-file deploy.bicep \
  --parameters prefix=$PREFIX \
  --parameters adminUsername="$ADMIN_USER_NAME" \
  --parameters adminPublicKey="$SSH_PUB_KEY" \
  --parameters sqlAdminUsername="$SQL_ADMIN_USER_NAME" \
  --parameters sqlAdminPassword="$SQL_ADMIN_PASSWD" \
  --parameters currentUserId="$CURRENT_USER_ID"