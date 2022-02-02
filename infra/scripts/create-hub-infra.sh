#!/usr/bin/env bash
#set -eo pipefail
trap exit SIGINT SIGTERM

# Load supporting script files
source ./scripts/utils.sh
source ./scripts/load-vars-from-config.sh
source ./scripts/create-and-load-ssh-keys.sh

# Set azure CLI to allow extension installation without prompt
az config set extension.use_dynamic_install=yes_without_prompt

# Set variable to track azure login
AZURE_LOGIN=0
# Login to azure and check if connected via cloud shell
# ./utils.sh
check_for_azure_login
check_for_cloud-shell

# If logged in, execute hub resource deployments
if [[ ${AZURE_LOGIN} -eq 1 ]]; then

echo '****************************************************'
echo "Starting hub infrastrucutre deployment."
echo '****************************************************'

# Create the Resource Group to deploy the Webinar Environment
az group create --name $RG_NAME --location $RG_LOCATION

echo "Deploying hub resources ..."
az deployment group create \
--name $ARM_DEPLOYMENT_NAME \
--mode Incremental \
--resource-group $RG_NAME \
--template-file ./scripts/hub-bicep/deploy.bicep \
--parameters prefix=$PREFIX \
--parameters adminUsername="$ADMIN_USER_NAME" \
--parameters adminPublicKey="$SSH_PUB_KEY" \
--parameters sqlAdminUsername="$SQL_ADMIN_USER_NAME" \
--parameters sqlAdminPassword="$SQL_ADMIN_PASSWD" \
--parameters currentUserId="$CURRENT_USER_ID"

# Save deployment outputs
mkdir -p outputs
az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o json --query properties.outputs | tee "./outputs/$RG_NAME-bicep-outputs.json"

echo '****************************************************'
echo "Hub infrastrucutre deployed successfully."
echo '****************************************************'

else
    # If the login variable isnt set to 1 due to login, then login must have failed in some way
    echo "Azure Login Failed"
    exit
fi