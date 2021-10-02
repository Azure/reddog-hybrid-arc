#!/usr/bin/env bash
# set -eo pipefail

########################################################################################
AZURE_LOGIN=0
########################################################################################
trap exit SIGINT SIGTERM

az config set extension.use_dynamic_install=yes_without_prompt

# check for the required extensions
check_dependencies() {
  # check if the dependencies are installed
  _NEEDED=(connectedk8s customlocation k8s-configuration)
  echo "Checking the dependencies for this script ... "

  for i in "${_NEEDED[@]}"
  do
      az $i --help > /dev/null 2> >(sed 's/hats//g') &&  echo " - az $i [found]" || { echo " - az $i [Not found]. Please install the $i extension before proceeding"; exit 1; }
  done
}

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

check_dependencies
check_for_azure_login
check_for_cloud-shell

if [[ ${AZURE_LOGIN} -eq 1 ]]; then
    ## Hub
    HUB_PATH="hub/bicep"
    BICEP_FILE="$HUB_PATH/deploy.bicep"
    export HUB_PATH BICEP_FILE

    bash "$HUB_PATH/scripts/run.sh"

    ## Branch
    BRANCH_PATH="branch/bicep"
    BICEP_FILE="$BRANCH_PATH/deploy.bicep"
    export BRANCH_PATH BICEP_FILE

    bash "$BRANCH_PATH/scripts/run.sh"
fi
