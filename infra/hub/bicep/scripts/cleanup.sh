source ./var.sh

rm -rf ssh_keys

az group delete -n $RG_NAME -y --no-wait