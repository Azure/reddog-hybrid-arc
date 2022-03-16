#!/usr/bin/env bash
#set -eo pipefail
trap exit SIGINT SIGTERM

# Load supporting script files
source ./scripts/utils.sh
source ./scripts/load-vars-from-config.sh
source ./scripts/create-and-load-ssh-keys.sh

# Set azure CLI to allow extension installation without prompt
az config set extension.use_dynamic_install=yes_without_prompt

# Set variable to track azure login
AZURE_LOGIN=0
# Login to azure and check if connected via cloud shell
# ./scripts/utils.sh
check_for_azure_login
check_for_cloud-shell

echo '****************************************************'
echo 'Starting hub configuration'
echo '****************************************************'

###########################################################
# Get AKS Cluster Credentials
echo '----------------------------------------------------'
echo 'Get AKS Cluster Credentials'
echo '----------------------------------------------------'
AKS_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .aksName.value)
az aks get-credentials \
    -n $AKS_NAME \
    -g $RG_NAME

###########################################################
# Azure SQL server must set firewall to allow azure services
echo '----------------------------------------------------'
echo "Opening Azure SQL Firewall"
echo '----------------------------------------------------'
AZURE_SQL_SERVER=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .sqlServerName.value)
echo "Allow access to Azure Services to Azure SQL"
az sql server firewall-rule create \
    --resource-group $RG_NAME \
    --server $AZURE_SQL_SERVER \
    --name AllowAzureServices \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0

###########################################################
# Setup Key Vault
echo '----------------------------------------------------'
echo 'Setting up Key Vault'
echo '----------------------------------------------------'

## Create SP for Key Vault Access
KV_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value)
echo "Key Vault: $KV_NAME"
echo "Create SP for KV use..."
az ad sp create-for-rbac \
    --name "http://sp-$RG_NAME.microsoft.com" \
    --create-cert \
    --cert $RG_NAME-cert \
    --keyvault $KV_NAME \
    --skip-assignment \
    --years 1
## Brian - added this need to test

## Get SP APP ID
echo "Getting SP_APPID ..."
SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
SP_APPID=$(echo $SP_INFO | jq -r .[].appId)
echo "AKV SP_APPID: $SP_APPID"        

## Get SP Object ID
echo "Getting SP_OBJECTID ..."
SP_OBJECTID=$(echo $SP_INFO | jq -r .[].objectId)
echo "AKV SP_OBJECTID: $SP_OBJECTID"

# Assign SP to KV with GET permissions
az keyvault set-policy \
    --name $KV_NAME \
    --object-id $SP_OBJECTID \
    --secret-permissions get  \
    --certificate-permissions get
# Assign permissions to the current user
UPN=$(az ad  signed-in-user show  -o json | jq -r '.userPrincipalName')
az keyvault set-policy \
    --name $KV_NAME \
    --secret-permissions get list set \
    --certificate-permissions create get list \
    --upn $UPN
az keyvault secret download \
    --vault-name $KV_NAME \
    --name $RG_NAME-cert \
    --encoding base64 \
    --file $SSH_KEY_PATH/kv-$RG_NAME-cert.pfx  

###########################################################
# Setup secret store CSI driver secret
echo '----------------------------------------------------'
echo 'Setting up the Secret Store CSI Driver'
echo '----------------------------------------------------'

# Deploy initial cluster resources
kubectl create ns reddog-retail
kubectl create secret generic \
    -n reddog-retail reddog.secretstore \
    --from-file=secretstore-cert=./ssh_keys/kv-$RG_NAME-cert.pfx \
    --from-literal=vaultName=$KV_NAME \
    --from-literal=spnClientId=$SP_APPID \
    --from-literal=spnTenantId=$TENANT_ID
###########################################################

###########################################################
# Install Zipkin
echo '----------------------------------------------------'
echo 'Installing Zipkin'
echo '----------------------------------------------------'
kubectl create ns zipkin
kubectl create deployment zipkin -n zipkin --image openzipkin/zipkin
kubectl expose deployment zipkin -n zipkin --type LoadBalancer --port 9411

###########################################################
# Add secrets to key vault
echo '----------------------------------------------------'
echo 'Adding secrets to Key Vault'
echo '----------------------------------------------------'

KV_NAME=$(jq -r .keyvaultName.value ./outputs/$RG_NAME-bicep-outputs.json)
echo "adding Key Vault Secrets"
# Service Bus
SB_NAME=$(jq -r .serviceBusName.value ./outputs/$RG_NAME-bicep-outputs.json)
SB_CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list \
    --resource-group $RG_NAME \
    --namespace-name  $SB_NAME \
    --name RootManageSharedAccessKey -o json| jq -r '.primaryConnectionString')
az keyvault secret set \
    --vault-name $KV_NAME \
    --name sb-root-connectionstring \
    --value "$SB_CONNECTION_STRING"

# Storage Account
SBLOB_NAME=$(jq -r .storageAccountName.value ./outputs/$RG_NAME-bicep-outputs.json)
az keyvault secret set \
    --vault-name $KV_NAME \
    --name sblob-storage-key \
    --value "$SBLOB_NAME"

# Cosmos DB
COSMOS_DB_NAME=$(jq -r .cosmosDbName.value ./outputs/$RG_NAME-bicep-outputs.json)
COSMOS_PRIMARY_RW_KEY=$(az cosmosdb keys list \
    -n $COSMOS_DB_NAME  -g $RG_NAME -o json | jq -r '.primaryMasterKey')
az keyvault secret set \
    --vault-name $KV_NAME \
    --name cosmos-primary-rw-key \
    --value "$COSMOS_PRIMARY_RW_KEY"

COSMOS_URI=$(az cosmosdb show \
    -n $COSMOS_DB_NAME -g $RG_NAME -o json | jq -r '.documentEndpoint')
az keyvault secret set \
    --vault-name $KV_NAME \
    --name cosmos-uri \
    --value "$COSMOS_URI"

# Azure SQL
AZURE_SQL_SERVER=$(jq -r .sqlServerName.value ./outputs/$RG_NAME-bicep-outputs.json)
#REDDOG_SQL_CONNECTION_STRING=$(az sql db show-connection-string --client ado.net --server ${AZURE_SQL_SERVER})
echo "SQL:${AZURE_SQL_SERVER}"
echo "USER:${SQL_ADMIN_USER_NAME}"
echo "PWD:${SQL_ADMIN_PASSWD}"
REDDOG_SQL_CONNECTION_STRING="Server=tcp:${AZURE_SQL_SERVER}.database.windows.net,1433;Database=reddoghub;User ID=${SQL_ADMIN_USER_NAME};Password=${SQL_ADMIN_PASSWD};Encrypt=true;Connection Timeout=30;"
echo "CONNECT:${REDDOG_SQL_CONNECTION_STRING}"
az keyvault secret set \
    --vault-name $KV_NAME \
    --name reddog-sql \
    --value "${REDDOG_SQL_CONNECTION_STRING}"

###########################################################
# GitOps
echo '----------------------------------------------------'
echo 'Connecting the cluster to Azure Arc'
echo '----------------------------------------------------'

AKS_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .aksName.value)
az connectedk8s connect -g $RG_NAME -n $AKS_NAME  --distribution aks

###########################################################
# Install the arc configuration
echo '----------------------------------------------------'
echo 'Applying Arc Cluster Configuration'
echo '----------------------------------------------------'
 # GitOps config for Hub AKS
 BRANCH=$(git branch --show-current)
 REPO_URL=$(git remote get-url origin)   
 AKS_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .aksName.value)
 az k8s-configuration create --name $RG_NAME-hub-deps \
 --cluster-name $AKS_NAME \
 --resource-group $RG_NAME \
 --scope cluster \
 --cluster-type connectedClusters \
 --operator-instance-name flux \
 --operator-namespace flux \
 --operator-params="--git-readonly --git-path=manifests/corporate/dependencies --git-branch=$BRANCH --manifest-generation=true" \
 --enable-helm-operator \
 --helm-operator-params='--set helm.versions=v3' \
 --repository-url $REPO_URL

 # wait for Dapr to start
 sleep 300
 provisioningState="Pending"
 while [[ $provisioningState != "Running" ]]; do
 provisioningState=$(kubectl get pod -n dapr-system -l app=dapr-operator -o jsonpath='{.items[0].status.phase}')
 echo "waiting for Dapr operator to start..."
 sleep 5
 done
 
 az k8s-configuration create --name $RG_NAME-hub-base \
 --cluster-name $AKS_NAME \
 --resource-group $RG_NAME \
 --scope namespace \
 --cluster-type connectedClusters \
 --operator-instance-name base \
 --operator-namespace reddog-retail \
 --operator-params="--git-readonly --git-path=manifests/corporate/base --git-branch=$BRANCH --manifest-generation=true" \
 --repository-url $REPO_URL

###########################################################
echo '----------------------------------------------------'
echo 'Creating the Hub UI App Service Plan'
echo '----------------------------------------------------'

az appservice plan create \
    --is-linux \
    -n ReddogAppServicePlan \
    -g $RG_NAME \
    --sku S1 \
    --number-of-workers 1 \
    -l $RG_LOCATION

###########################################################
echo '----------------------------------------------------'
echo 'Deploying the hub UI'
echo '----------------------------------------------------'

#az extension remove --name appservice-kube
az webapp create \
    -n $RG_NAME-ui \
    -g $RG_NAME \
    -p ReddogAppServicePlan \
    -i ghcr.io/azure/reddog-retail-demo/reddog-retail-ui:latest

ACCOUNTING_IP=$(kubectl get svc accounting-service -n reddog-retail -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ $ACCOUNTING_IP == "" ]]; do
ACCOUNTING_IP=$(kubectl get svc accounting-service -n reddog-retail -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Waiting for accounting service..."
sleep 5
done

MAKELINE_IP=$(kubectl get svc make-line-service -n reddog-retail -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ $MAKELINE_IP == "" ]]; do
MAKELINE_IP=$(kubectl get svc make-line-service -n reddog-retail -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Waiting for make line service..."
sleep 5
done

ORDER_IP=$(kubectl get svc order-service -n reddog-retail -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ $ORDER_IP == "" ]]; do
ORDER_IP=$(kubectl get svc order-service -n reddog-retail -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Waiting for order service..."
sleep 5
done

cat > settings.json << EOL
[
  {
    "name": "NODE_ENV",
    "slotSetting": false,
    "value": "production"
  },
  {
    "name": "VUE_APP_ACCOUNTING_BASE_URL",
    "slotSetting": false,
    "value": "http://$ACCOUNTING_IP:8083"
  },
  {
    "name": "VUE_APP_IS_CORP",
    "slotSetting": false,
    "value": "true"
  },
  {
    "name": "VUE_APP_MAKELINE_BASE_URL",
    "slotSetting": false,
    "value": "http://$MAKELINE_IP:8082"
  },
  {
    "name": "VUE_APP_ORDER_BASE_URL",
    "slotSetting": false,
    "value": "http://$ORDER_IP:8084"
  },
  {
    "name": "VUE_APP_SITE_TITLE",
    "slotSetting": false,
    "value": "Red Dog Pharmacy"
  },
  {
    "name": "VUE_APP_SITE_TYPE",
    "slotSetting": false,
    "value": "Pharmacy"
  },
  {
    "name": "VUE_APP_STORE_ID",
    "slotSetting": false,
    "value": "Corp"
  }
]
EOL
az webapp config appsettings set -g $RG_NAME -n $RG_NAME-ui --settings @settings.json
rm settings.json
###########################################################


echo '****************************************************'
echo 'Hub configured successfully.'
echo '****************************************************'