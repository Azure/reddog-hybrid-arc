#!/bin/bash

echo 'Creating cluster for RG:'$RG_NAME

# Create the Resource Group to deploy the Webinar Environment
az group create --name $RG_NAME --location $RG_LOCATION

# Create a user assigned managed identity for the jump server
echo "Creating jump box managed identity"
MANAGED_IDENTITY=$(az identity create -n jumpbox-identity -g $RG_NAME -o json)
MI_APP_ID=$(echo $MANAGED_IDENTITY|jq -r .clientId)
MI_RESOURCE_ID=$(echo $MANAGED_IDENTITY|jq -r .id)

# Grant the user assigned managed identity Contributor on the Resource Group
echo "Granting the jump box identity contributor on the resource group...."
until az role assignment create --assignee $MI_APP_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION/resourcegroups/$RG_NAME" 2>/dev/null
do
  sleep 10
  echo "Waiting on role assignment..."
done

# Deploy the jump server and K3s cluster
echo "Deploying branch office resources...."
az deployment group create \
  --name $ARM_DEPLOYMENT_NAME \
  --mode Incremental \
  --resource-group $RG_NAME \
  --template-file deploy.bicep \
  --parameters prefix=$PREFIX \
  --parameters k3sToken="$K3S_TOKEN" \
  --parameters adminUsername="$ADMIN_USER_NAME" \
  --parameters adminPublicKey="$SSH_PUB_KEY" \
  --parameters jumpManagedIdentity="$MI_RESOURCE_ID"

# Get the jump server public IP
JUMP_IP=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.publicIP.value)
echo "Jump box connection info: $ADMIN_USER_NAME@$JUMP_IP"

# Get the host name for the control host
CONTROL_HOST_NAME=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.controlName.value)

# Copy the private key up to the jump server to be used to access the rest of the nodes
echo "Copying private key to jump server..."
scp -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/id_rsa $SSH_KEY_PATH/id_rsa $ADMIN_USER_NAME@$JUMP_IP:~/.ssh

# Execute setup script on jump server
echo "Executing setup script on jump server...."
ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/id_rsa $ADMIN_USER_NAME@$JUMP_IP "curl -sfL https://raw.githubusercontent.com/swgriffith/azure-guides/master/temp/get-kube-config.sh |CONTROL_HOST=$CONTROL_HOST_NAME sh -"

# Get managd identity object id
MI_OBJ_ID=$(az ad sp show --id $MI_APP_ID -o tsv --query objectId)

# Arc join the cluster
echo "Arc joining the branch cluster..."
ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/id_rsa $ADMIN_USER_NAME@$JUMP_IP "az connectedk8s connect -g $RG_NAME -n $PREFIX-branch --distribution k3s --infrastructure generic --custom-locations-oid $MI_OBJ_ID"