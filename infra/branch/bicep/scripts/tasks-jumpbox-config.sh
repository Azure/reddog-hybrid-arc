# Get the jump server public IP
JUMP_IP=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.publicIP.value)

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
scp -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP:~/.ssh/id_rsa


# Install K3s
# Get the host name for the control host
CONTROL_HOST_NAME=$(az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o tsv --query properties.outputs.controlName.value)
echo "Control Host Name: $CONTROL_HOST_NAME"

# Execute setup script on jump server
echo "Executing setup script on jump server...."
ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP "curl -sfL https://raw.githubusercontent.com/swgriffith/azure-guides/master/temp/get-kube-config.sh |CONTROL_HOST=$CONTROL_HOST_NAME sh -"
