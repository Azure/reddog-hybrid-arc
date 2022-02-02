#!/usr/bin/env bash
set -eo pipefail

source ./scripts/load-vars-from-config.sh
source ./scripts/create-and-load-ssh-keys.sh cleanup

# Delete SSH Keys
rm -rf $SSH_KEY_PATH

# Delete logs
rm -rf logs

# Delete outputs
rm -rf outputs

# Delete Hub Resource Group
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait