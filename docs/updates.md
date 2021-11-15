## Updates

#### Corp 

KV cert
KV secrets 
GitOps dependencies (Dapr)
GitOps app
SQL Setup
UI 
Corp Tx Service
APIM

```bash
export RG_NAME=intials-reddog-corp-eastus
export OUTPUT="./outputs/br-reddog-corp-eastus-bicep-outputs.json"
export TENANT_ID=""

## Create SP for Key Vault Access (something not working here with JQ)
KV_NAME=$(cat $OUTPUT | jq -r .keyvault.value.name)
KV_NAME="br2-hub-hub-kv-dhmg"
echo "Key Vault: $KV_NAME"
echo "Create SP for KV use..."
az ad sp create-for-rbac --name "http://sp-$RG_NAME.microsoft.com" --create-cert --cert $RG_NAME-cert --keyvault $KV_NAME --skip-assignment --years 1
## Get SP APP ID
echo "Get SP_APPID..."
SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
SP_APPID=$(echo $SP_INFO | jq -r .[].appId)
export SP_APPID=$(az ad sp show --id "http://sp-br2-reddog-corp-eastus.microsoft.com" -o tsv --query "appId")
echo $SP_APPID
echo "AKV SP_APPID: $SP_APPID"
## Get SP Object ID
echo "Get SP_OBJECTID..."
SP_OBJECTID=$(echo $SP_INFO | jq -r .[].objectId)
echo "AKV SP_OBJECTID: $SP_OBJECTID"
# Assign SP to KV with GET permissions
az keyvault set-policy --name $KV_NAME --object-id $SP_OBJECTID --secret-permissions get
az keyvault secret download --vault-name $KV_NAME --name $RG_NAME-cert --encoding base64 --file $SSH_KEY_PATH/kv-$RG_NAME-cert.pfx

kubectl create ns reddog-retail

kubectl create secret generic -n reddog-retail reddog.secretstore --from-file=secretstore-cert=kv-$RG_NAME-cert.pfx --from-literal=vaultName=$KV_NAME --from-literal=spnClientId=$SP_APPID --from-literal=spnTenantId=$TENANT_ID

kubectl create secret generic -n reddog-retail reddog.secretstore --from-file=secretstore-cert=kv-br2-reddog-corp-eastus-cert.pfx --from-literal=vaultName=$KV_NAME --from-literal=spnClientId=$SP_APPID --from-literal=spnTenantId=$TENANT_ID

# Zipkin
kubectl create ns zipkin
kubectl create deployment zipkin -n zipkin --image openzipkin/zipkin
kubectl expose deployment zipkin -n zipkin --type LoadBalancer --port 9411

# add Corp KV secrets
blob-storage-key (password only)
cosmos-primary-rw-key
cosmos-uri
sb-root-connectionstring
reddog-sql 

# GitOps
export AKSNAME=br2-hub-aks
az connectedk8s connect -g $RG_NAME -n $AKSNAME --distribution aks

az k8s-configuration create --name $RG_NAME-hub-deps \
--cluster-name $AKSNAME \
--resource-group $RG_NAME \
--scope cluster \
--cluster-type connectedClusters \
--operator-instance-name flux \
--operator-namespace flux \
--operator-params="--git-readonly --git-path=manifests/corporate/dependencies --git-branch=main --manifest-generation=true" \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url git@github.com:Azure/reddog-retail-demo.git \
--ssh-private-key "$(cat arc-priv-key-b64)"

az k8s-configuration create --name $RG_NAME-hub-base \
--cluster-name $AKSNAME \
--resource-group $RG_NAME \
--scope namespace \
--cluster-type connectedClusters \
--operator-instance-name base \
--operator-namespace reddog-retail \
--operator-params="--git-readonly --git-path=manifests/corporate/base --git-branch=main --manifest-generation=true" \
--repository-url git@github.com:Azure/reddog-retail-demo.git \
--ssh-private-key "$(cat arc-priv-key-b64)"

az k8s-configuration list --cluster-name $AKSNAME --resource-group $RG_NAME --cluster-type connectedClusters

az k8s-configuration delete --cluster-name $AKSNAME --resource-group $RG_NAME --name $RG_NAME-hub-base --cluster-type connectedClusters

# UI
Add env variables to Hub UI App Service

# For each, you'd have something like http://20.81.34.83:8083 Each one has a specific port
VUE_APP_ACCOUNTING_BASE_URL
VUE_APP_MAKELINE_BASE_URL
VUE_APP_ORDER_BASE_URL
NODE_ENV=production
VUE_APP_IS_CORP=true
VUE_APP_SITE_TITLE=My Company Name # this one will show up on the UI title
VUE_APP_SITE_TYPE=Pharmacy
VUE_APP_STORE_ID=Corp # I don't think this one is used for Corp. Just for the branches
```

#### Corp Transfer Function

```bash

# Manually create 2 queues/bindings in Rabbit MQ
corp-transfer-orders
corp-transfer-ordercompleted

# KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --version 2.0.0 --create-namespace --namespace keda

func kubernetes deploy --name corp-transfer-service --javascript --registry ghcr.io/cloudnativegbb/paas-vnext --polling-interval 20 --cooldown-period 300 --dry-run > func-deployment.yaml

# Container
docker login ghcr.io
docker build -t ghcr.io/cloudnativegbb/paas-vnext/corp-transfer-service:1.0 .
docker push ghcr.io/cloudnativegbb/paas-vnext/corp-transfer-service:1.0

# Corp Transfer Service Secret (need to run the func deploy and edit to only include secret)
kubectl apply -f ./manifests/corp-transfer-secret.yaml -n reddog-retail
kubectl apply -f ./manifests/corp-transfer-fx.yaml -n reddog-retail

```


#### Lima / APIM 

```bash

chmod 600 ./ssh_keys/brian_id_rsa

export RG_NAME=brian-reddog-atlanta-eastus
export CLUSTER=brianatlanta-k3s

az connectedk8s connect -g $RG_NAME -n $CLUSTER
az connectedk8s delete -g $RG_NAME -n $CLUSTER

# Arc join the cluster
  # Get managed identity object id
  MI_BASENAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value | sed 's/-kv.*//g')
  MI_SUFFIX="branchManagedIdentity"
  MI_APP_ID=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .userAssignedMIAppID.value)
  #MI_OBJ_ID=$(az ad sp show --id $MI_APP_ID -o tsv --query objectId)
  MI_OBJ_ID=$(az identity show -n ${MI_BASENAME}${MI_SUFFIX} -g $RG_NAME | jq -r .principalId)

  az identity show -n brianatlantabranchManagedIdentity -g $RG_NAME
  MI_OBJ_ID=""
  
  echo "User Assigned Managed Identity App ID: $MI_APP_ID"
  echo "User Assigned Managed Identity Object ID: $MI_OBJ_ID"

  User Assigned Managed Identity App ID: 
  User Assigned Managed Identity Object ID: 

az connectedk8s connect -g $RG_NAME -n $CLUSTER --distribution k3s --infrastructure generic --custom-locations-oid $MI_OBJ_ID

az connectedk8s show --name $CLUSTER --resource-group $RG_NAME -o json

# Lima
https://docs.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=bash

az k8s-extension create \
    --resource-group $RG_NAME \
    --name "appservice-ext" \
    --cluster-type connectedClusters \
    --cluster-name $CLUSTER \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace "appservice-ns" \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=appservice-ns" \
    --configuration-settings "clusterName=reddog-kube-env" \
    --configuration-settings "loadBalancerIp=1.1.1.1" \
    --configuration-settings "keda.enabled=false" \
    --configuration-settings "buildService.storageClassName=local-path" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=appservice-ns/kube-environment-config" 

watch az k8s-extension show --cluster-type connectedClusters --cluster-name $CLUSTER --resource-group $RG_NAME --name appservice-ext -o table

az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $CLUSTER \
    --resource-group $RG_NAME \
    --name appservice-ext -o json

az k8s-extension delete \
    --cluster-type connectedClusters \
    --cluster-name $CLUSTER \
    --resource-group $RG_NAME \
    --name appservice-ext

extensionId=$(az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $CLUSTER \
    --resource-group $RG_NAME \
    --name appservice-ext \
    --query id \
    --output tsv)    

customLocationName="atlanta-custom-loc"

connectedClusterId=$(az connectedk8s show --resource-group $RG_NAME --name $CLUSTER --query id --output tsv)    

az ad sp show --id '' --query objectId -o tsv

az connectedk8s enable-features -n $CLUSTER -g $RG_NAME --custom-locations-oid "51dfe1e8-70c6-4de5-a08e-e18aff23d815" --features cluster-connect custom-locations

az customlocation create \
    --resource-group $RG_NAME \
    --name $customLocationName \
    --host-resource-id $connectedClusterId \
    --namespace "appservice-ns" \
    --cluster-extension-ids $extensionId

az customlocation show --resource-group $RG_NAME --name $customLocationName

customLocationId=$(az customlocation show \
    --resource-group $RG_NAME \
    --name $customLocationName \
    --query id \
    --output tsv)

az extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl"

export KUBEENVNAME="reddog-kube-env"

az appservice kube create \
    --resource-group $RG_NAME \
    --name $KUBEENVNAME \
    --custom-location $customLocationId \
    --static-ip ""

az appservice kube show --resource-group $RG_NAME --name $KUBEENVNAME

az webapp create \
    --resource-group $RG_NAME \
    --name briar-test \
    --custom-location $customLocationId \
    --runtime 'NODE|12-lts'

http://briar-test.reddog-kube-env-114mjqcn.eastus.k4apps.io    

# APIM
https://docs.microsoft.com/en-us/azure/api-management/how-to-deploy-self-hosted-gateway-azure-arc

az k8s-extension create \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --resource-group $RG_NAME \
    --name apim-arc \
    --extension-type Microsoft.ApiManagement.Gateway \
    --scope namespace \
    --target-namespace apim-arc \
    --configuration-settings gateway.endpoint='https://br-reddog-apim.management.azure-api.net/subscriptions/471d33fd-a776-405b-947c-467c291dc741/resourceGroups/br-reddog-casper-eastus/providers/Microsoft.ApiManagement/service/br-reddog-apim?api-version=2021-01-01-preview' \
    --configuration-protected-settings gateway.authKey='GatewayKey reddog&202110231850&nsr2+8l079LdVvGH3hjaHSNxhbQvrvauXtzmvrhtujVwlkJ9wMZhqMakeyBnavOSf15SPF7j0r6XkCJwRk9T+Q==' \
    --configuration-settings service.type='NodePort' \
    --release-train preview

az k8s-extension show --cluster-type connectedClusters --cluster-name $RG_NAME-branch --resource-group $RG_NAME --name apim-arc

```

#### Cleanup stuff

```bash
http://<IP Address>:15672

sqlcmd -S 10.128.1.4 -U reddogadmin -P ""

export REDISIP=""
export REDISPWD=""
redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 keys "loyalty*" | xargs redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 DEL
redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 keys "make*" | xargs redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 DEL



```