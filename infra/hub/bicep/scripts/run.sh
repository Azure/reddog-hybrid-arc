#!/usr/bin/env bash
# Requirements:
# - Azure CLI
# - jq
#set -Ee -o pipefail

########################################################################################
AZURE_LOGIN=0 
########################################################################################
trap exit SIGINT SIGTERM

# checks if we are running in cloud-shell.
# if yes, we need to login to Azure first. Otherwise some commands will fail.
check_for_cloud-shell() {
  if [[ $AZUREPS_HOST_ENVIRONMENT =~ ^cloud-shell.* ]]; then
	echo
        echo '****************************************************'
        echo ' Please login to Azure before proceeding.'
        echo '****************************************************'
        echo ' In cloud-shell, you need to do az login as a workaround before' 
        echo ' creating the service principal below.' 
        echo
        echo ' reference: https://github.com/Azure/azure-cli/issues/11749#issuecomment-570975762'
        az login
  fi
  # we are logged in at this point
  AZURE_LOGIN=1
  export AZURE_LOGIN
}

check_for_azure_login() {
  # run a command against Azure to check if we are logged in already.
  az group list
  # save the return code from above. Anything different than 0 means we need to login
  AZURE_LOGIN=$?

  if [[ ${AZURE_LOGIN} -ne 0 ]]; then
      # not logged in. Initiate login process
      az login
      export AZURE_LOGIN

  fi
}

# inherit_exit is available on bash >= 4 
if [[ "${BASH_VERSINFO:-0}" -ge 4 ]]; then
	shopt -s inherit_errexit
fi
trap "echo ERROR: Please check the error messages above." ERR

check_dependencies() {
  # check if the dependencies are installed
  _NEEDED="az jq"

  printf "Checking dependencies on the Hub ... "
  for i in seq ${_NEEDED}
    do
      if hash "$i" 2>/dev/null; then
      # do nothing
        :
      else
        echo -e "\t $_ not installed".
        _DEP_FLAG=true
      fi
    done

  if [[ "${_DEP_FLAG}" == "true" ]]; then
    echo -e "\nDependencies missing. Please fix that before proceeding"
    exit 1
  fi
  printf "done.\n"
}

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

  CLUSTER_IP_ADDRESS=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterIP.value)
  CLUSTER_FQDN=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterFQDN.value)

  echo '****************************************************'
  echo "Hub deployed successfully"
  echo '****************************************************'
}

check_dependencies
check_for_azure_login
check_for_cloud-shell
show_params
create_hub
