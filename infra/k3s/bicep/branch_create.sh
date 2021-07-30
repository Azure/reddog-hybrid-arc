#!/bin/bash

echo "Branch Parameters"
echo "------------------------------------------------"
echo 'Creating cluster for RG:'$RG_NAME
echo "ARM_DEPLOYMENT_NAME: $ARM_DEPLOYMENT_NAME"
echo "SUBSCRIPTION: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"
echo "K3S_TOKEN: $K3S_TOKEN"
echo "ADMIN_USER_NAME: $ADMIN_USER_NAME"
echo "SSH_KEY_PATH: $SSH_KEY_PATH"
echo "------------------------------------------------"

# Set the Subscriptoin
az account set --subscription $SUBSCRIPTION_ID

# Create the Resource Group to deploy the Webinar Environment
az group create --name $RG_NAME --location $RG_LOCATION

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
  --parameters adminPublicKey="$SSH_PUB_KEY" 


# Get the jump server public IP
JUMP_IP=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.publicIP.value)
echo "Jump box connection info: ssh $ADMIN_USER_NAME@$JUMP_IP -i $SSH_KEY_PATH/id_rsa"

# Get the host name for the control host
CONTROL_HOST_NAME=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.controlName.value)
echo "Control Host Name: $CONTROL_HOST_NAME"

# Get the host name for the control host
JUMP_VM_NAME=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.jumpVMName.value)
echo "Jump Host Name: $JUMP_VM_NAME"

echo "Wait for jump server to start"
while [[ "$(az vm list -d -g $RG_NAME -o tsv --query "[?name=='$JUMP_VM_NAME'].powerState")" != "VM running" ]]
do
echo "Waiting...."
  sleep 5
done
echo "Jump Server Running!"

# Give the VM a few more seconds to become available
sleep 20

# Copy the private key up to the jump server to be used to access the rest of the nodes
echo "Copying private key to jump server..."
scp -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/id_rsa $SSH_KEY_PATH/id_rsa $ADMIN_USER_NAME@$JUMP_IP:~/.ssh

# Execute setup script on jump server
echo "Executing setup script on jump server...."
ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/id_rsa $ADMIN_USER_NAME@$JUMP_IP "curl -sfL https://raw.githubusercontent.com/swgriffith/azure-guides/master/temp/get-kube-config.sh |CONTROL_HOST=$CONTROL_HOST_NAME sh -"

# Get managd identity object id
MI_APP_ID=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.userAssignedMIAppID.value)
MI_OBJ_ID=$(az ad sp show --id $MI_APP_ID -o tsv --query objectId)
echo "User Assigned Managed Identity App ID: $MI_APP_ID"
echo "User Assigned Managed Identity Object ID: $MI_OBJ_ID"

# Arc join the cluster
echo "Arc joining the branch cluster..."
ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/id_rsa $ADMIN_USER_NAME@$JUMP_IP "az connectedk8s connect -g $RG_NAME -n $PREFIX-branch --distribution k3s --infrastructure generic --custom-locations-oid $MI_OBJ_ID"