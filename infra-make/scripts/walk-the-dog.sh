#!/usr/bin/env bash
#set -eo pipefail

BASEDIR=$(pwd | sed 's!infra.*!!g')
source $BASEDIR/infra/common/utils.subr

########################################################################################
AZURE_LOGIN=0
########################################################################################
trap exit SIGINT SIGTERM

az config set extension.use_dynamic_install=yes_without_prompt

check_dependencies
check_for_azure_login
check_for_cloud-shell

if [[ ${AZURE_LOGIN} -eq 1 ]]; then
    # Hub
    HUB_PATH="hub/bicep"
    BICEP_FILE="$HUB_PATH/deploy.bicep"
    export HUB_PATH BICEP_FILE

    bash "$HUB_PATH/scripts/run.sh"
  
    # ## Branch
    # BRANCH_PATH="branch/bicep"
    # BICEP_FILE="$BRANCH_PATH/deploy.bicep"
    # export BRANCH_PATH BICEP_FILE

    # bash "$BRANCH_PATH/scripts/run.sh"
fi