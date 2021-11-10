#!/usr/bin/env bash
# Requirements:
# - Azure CLI
# - jq
set -Ee -o pipefail
BASEDIR=$(pwd | sed 's!infra.*!!g')

source $BASEDIR/infra/common/utils.subr
source $BASEDIR/infra/common/corp.subr

########################################################################################
AZURE_LOGIN=0 
########################################################################################
trap exit SIGINT SIGTERM

# Show Params
show_params() {

  # Set Variables from var.sh
  source ./var.sh

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
}

create_hub() {
  # Create the Resource Group to deploy the Webinar Environment
  az group create --name $RG_NAME --location $RG_LOCATION

  echo "Deploying hub resources ..."
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

  # Save deployment outputs
  mkdir -p outputs
  az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o json --query properties.outputs | tee "./outputs/$RG_NAME-bicep-outputs.json"

  echo '****************************************************'
  echo "Hub deployed successfully."
  echo "Next: Configuring the cluster."
  echo '****************************************************'
}

check_dependencies
check_for_azure_login
check_for_cloud-shell
show_params

#
# hub creation
create_hub
aks_get_credentials

# # SQL setup
sql_allow_firewall

# # Key Vault setup and certs & secrets
kv_init
reddog_create_k8s_secrets

# # GitOps dependencies
zipkin_init

# Add secrets to Key Vault
kv_add_secrets

# # GitOps app
gitops_aks_connect_cluster
gitops_configuration_create hub

# UI
appservice_plan_init
webapp_init

# APIM