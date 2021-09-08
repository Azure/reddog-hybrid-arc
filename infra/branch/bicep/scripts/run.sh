# Set Variables from var.sh
source ./var.sh

# Show Params
show_params() {
# Get RG Prefix
echo "Parameters"
echo "------------------------------------------------"
echo "ARM_DEPLOYMENT_NAME: $ARM_DEPLOYMENT_NAME"
echo "RG_PREFIX: $PREFIX"
echo "SUBSCRIPTION: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"
echo "K3S_TOKEN: $K3S_TOKEN"
echo "ADMIN_USER_NAME: $ADMIN_USER_NAME"
echo "SSH_KEY_PATH: $SSH_KEY_PATH"
echo "SSH_KEY_NAME: $SSH_KEY_PATH/$SSH_KEY_NAME"
echo "SSH_PUB_KEY: $SSH_PUB_KEY"
echo "------------------------------------------------"
}


# Loop through $BRANCHES (from config.json) and create branches
create_branches() {
for branch in $BRANCHES
do
export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-reddog-$BRANCH_NAME-$RG_LOCATION

# Create log directory
mkdir -p logs

# Create Branch
create_branch > ./logs/$RG_NAME.log 2>&1 &
done

# wait for all pids
echo "Waiting for branch creation to complete..."
echo "Check the log files in ./logs for individual branch creation status"
wait
}

# Create Branch
create_branch() {
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
  --template-file $BICEP_FILE \
  --parameters prefix=$PREFIX$BRANCH_NAME \
  --parameters k3sToken="$K3S_TOKEN" \
  --parameters adminUsername="$ADMIN_USER_NAME" \
  --parameters adminPublicKey="$SSH_PUB_KEY" \
  --parameters currentUserId="$CURRENT_USER_ID" \
  --parameters rabbitmqconnectionstring="amqp://contosoadmin:$RABBIT_MQ_PASSWD@rabbitmq.rabbitmq.svc.cluster.local:5672" \
  --parameters redispassword=$REDIS_PASSWD

# Save deployment outputs
mkdir -p outputs
az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o json --query properties.outputs > "./outputs/$RG_NAME-bicep-outputs.json"

CLUSTER_IP_ADDRESS=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterIP.value)
CLUSTER_FQDN=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterFQDN.value)

# Get the host name for the control host
JUMP_VM_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .jumpVMName.value)
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

# Get the jump server public IP
JUMP_IP=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .publicIP.value)

run_on_jumpbox () {
  ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP $1
}

# Copy the private key up to the jump server to be used to access the rest of the nodes
echo "Copying private key to jump server..."
scp -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP:~/.ssh/id_rsa || true

# Execute setup script on jump server
# Get the host name for the control host
CONTROL_HOST_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .controlName.value)
echo "Control Host Name: $CONTROL_HOST_NAME"
echo "Executing setup script on jump server...."
run_on_jumpbox "curl -sfL https://raw.githubusercontent.com/swgriffith/azure-guides/master/temp/get-kube-config.sh |CONTROL_HOST=$CONTROL_HOST_NAME sh -"

# Deploy initial cluster resources
echo "Creating Namespaces...."
run_on_jumpbox "kubectl create ns reddog-retail;kubectl create ns rabbitmq;kubectl create ns redis;kubectl create ns dapr-system"

echo "Creating RabbitMQ and Redis Password Secrets...."
run_on_jumpbox "kubectl create secret generic -n rabbitmq rabbitmq-password --from-literal=rabbitmq-password=$RABBIT_MQ_PASSWD"
run_on_jumpbox "kubectl create secret generic -n redis redis-password --from-literal=redis-password=$REDIS_PASSWD"

# Arc join the cluster
# Get managd identity object id
MI_APP_ID=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .userAssignedMIAppID.value)
MI_OBJ_ID=$(az ad sp show --id $MI_APP_ID -o tsv --query objectId)
echo "User Assigned Managed Identity App ID: $MI_APP_ID"
echo "User Assigned Managed Identity Object ID: $MI_OBJ_ID"

echo "Arc joining the branch cluster..."
run_on_jumpbox "az connectedk8s connect -g $RG_NAME -n $RG_NAME-branch --distribution k3s --infrastructure generic --custom-locations-oid $MI_OBJ_ID"

## Create SP for Key Vault Access
KV_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value)
echo "Key Vault: $KV_NAME"
echo "Create SP for KV use..."
az ad sp create-for-rbac --name "http://sp-$RG_NAME.microsoft.com" --create-cert --cert $RG_NAME-cert --keyvault $KV_NAME --skip-assignment --years 1
## Get SP APP ID
echo "Get SP_APPID..."
SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
SP_APPID=$(echo $SP_INFO | jq -r .[].appId)
echo "AKV SP_APPID: $SP_APPID"
## Get SP Object ID
echo "Get SP_OBJECTID..."
SP_OBJECTID=$(echo $SP_INFO | jq -r .[].objectId)
echo "AKV SP_OBJECTID: $SP_OBJECTID"
# Assign SP to KV with GET permissions
az keyvault set-policy --name $KV_NAME --object-id $SP_OBJECTID --secret-permissions get
az keyvault secret download --vault-name $KV_NAME --name $RG_NAME-cert --encoding base64 --file $SSH_KEY_PATH/kv-$RG_NAME-cert.pfx
# copy pfx file to jump box and create secret there
scp -i $SSH_KEY_PATH/$SSH_KEY_NAME $SSH_KEY_PATH/kv-$RG_NAME-cert.pfx $ADMIN_USER_NAME@$JUMP_IP:~/kv-$RG_NAME-cert.pfx
# Set k8s secret from jumpbox
run_on_jumpbox "kubectl create secret generic -n reddog-retail reddog.secretstore --from-file=secretstore-cert=kv-$RG_NAME-cert.pfx --from-literal=vaultName=$KV_NAME --from-literal=spnClientId=$SP_APPID --from-literal=spnTenantId=$TENANT_ID"

az k8s-configuration create --name $RG_NAME-branch-deps \
--cluster-name $RG_NAME-branch \
--resource-group $RG_NAME \
--scope cluster \
--cluster-type connectedClusters \
--operator-instance-name flux \
--operator-namespace flux \
--operator-params='--git-readonly --git-path=manifests/branch/dependencies --git-branch=sg-branch-infra --manifest-generation=true' \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url git@github.com:Azure/reddog-retail-demo.git \
--ssh-private-key "$(cat arc-priv-key-b64)"

# Wait 2 minutes for deps to deploy
echo "Waiting 120 seconds for Dependencies to deploy before installing base reddog-retail configs"
sleep 120 

az k8s-configuration create --name $RG_NAME-branch-base \
--cluster-name $RG_NAME-branch \
--resource-group $RG_NAME \
--scope namespace \
--cluster-type connectedClusters \
--operator-instance-name base \
--operator-namespace reddog-retail \
--operator-params='--git-readonly --git-path=manifests/branch/base --git-branch=sg-branch-infra --manifest-generation=true' \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url git@github.com:Azure/reddog-retail-demo.git \
--ssh-private-key "$(cat arc-priv-key-b64)"

echo '****************************************************'
echo 'Deployment Complete!'
echo "Jump box connection info: ssh $ADMIN_USER_NAME@$JUMP_IP -i $SSH_KEY_PATH/$SSH_KEY_NAME"
echo "Cluster connection info: http://$CLUSTER_IP_ADDRESS:8081 or http://$CLUSTER_FQDN:8081"
echo '****************************************************'
}


# Execute Functions
show_params
create_branches