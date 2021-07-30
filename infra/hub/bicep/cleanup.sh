export PREFIX=$(cat infra.json|jq -r '.hub.rgNamePrefix')
export RG_LOCATION=$(cat infra.json|jq -r '.hub.location')
export RG_NAME=$PREFIX-hub-$RG_LOCATION

az group delete -n $RG_NAME -y --no-wait

rm -rf ssh_keys
