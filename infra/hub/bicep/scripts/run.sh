#!/bin/bash

# Set Variables from var.sh
source ./var.sh

# Show Params
echo "Parameters"
echo "------------------------------------------------"
echo "ARM_DEPLOYMENT_NAME: $ARM_DEPLOYMENT_NAME"
echo "SUBSCRIPTION: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"
echo "RG_NAME": $RG_NAME
echo "ADMIN_USER_NAME: $ADMIN_USER_NAME"
echo "SSH_KEY_PATH: $SSH_KEY_PATH"
echo "SQL_ADMIN_USER_NAME: $SQL_ADMIN_USER_NAME"
echo "SQL_ADMIN_PASSWD: $SQL_ADMIN_PASSWD"
echo "------------------------------------------------"

# Create the Resource Group to deploy the Webinar Environment
az group create --name $RG_NAME --location $RG_LOCATION

echo "Deploying hub resources...."
az deployment group create \
  --name $ARM_DEPLOYMENT_NAME \
  --mode Incremental \
  --resource-group $RG_NAME \
  --template-file $BICEP_FILE \
  --parameters prefix=$PREFIX \
  --parameters adminUsername="$ADMIN_USER_NAME" \
  --parameters adminPublicKey="$SSH_PUB_KEY" \
  --parameters sqlAdminUsername="$SQL_ADMIN_USER_NAME" \
  --parameters sqlAdminPassword="$SQL_ADMIN_PASSWD" \
  --parameters currentUserId="$CURRENT_USER_ID"