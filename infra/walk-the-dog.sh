#!/usr/bin/env bash
#set -eo pipefail

az config set extension.use_dynamic_install=yes_without_prompt

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
