# Delete Logs
rm *.log

# Delete SSH Keys
rm -rf ssh_keys

# Delete Resource Groups
for branch in $(cat infra.json|jq -c '.branches[]')
do
export PREFIX=$(echo $branch|jq -r '.rgNamePrefix')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-$RG_LOCATION

# Create Branch
echo "Deleting Resource Group: $RG_NAME"
az group delete -n $RG_NAME -y --no-wait
done