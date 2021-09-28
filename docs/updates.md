## Updates

#### Corp 

* KV cert
* KV secrets 
GitOps dependencies (Dapr)
GitOps app
SQL Setup
UI 
Corp Tx Service

```bash
export RG_NAME=br2-reddog-corp-eastus
export OUTPUT="./outputs/br-reddog-corp-eastus-bicep-outputs.json"
export TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"

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

# SQL Server - must set firewall to allow Azure services

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
NODE_ENV
VUE_APP_ACCOUNTING_BASE_URL
VUE_APP_IS_CORP
VUE_APP_MAKELINE_BASE_URL
VUE_APP_ORDER_BASE_URL
VUE_APP_SITE_TITLE
VUE_APP_SITE_TYPE
VUE_APP_STORE_ID

App Service - Setup container based deploy of UI

ghcr.io/azure/reddog-retail-demo/reddog-retail-ui:3844603
https://reddog-corp.azurewebsites.net
```

#### Corp Transfer Function

```bash

ssh reddogadmin@40.71.190.175 -i ./ssh_keys/br2_id_rsa

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

http://br2toronto-k3s-worker-pub-ip.eastus.cloudapp.azure.com:8081/#/dashboard

```


#### Lima / APIM 

```bash

export RG_NAME=br-reddog-casper-eastus
az connectedk8s show --name $RG_NAME-branch --resource-group $RG_NAME -o json

# Lima
https://docs.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=bash

az k8s-extension create \
    --resource-group $RG_NAME \
    --name "appservice-ext" \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace "appservice-ns" \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=appservice-ns" \
    --configuration-settings "clusterName=reddog-kube-env" \
    --configuration-settings "loadBalancerIp=52.149.145.107" \
    --configuration-settings "keda.enabled=false" \
    --configuration-settings "buildService.storageClassName=local-path" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=appservice-ns/kube-environment-config" 

az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --resource-group $RG_NAME \
    --name appservice-ext -o json

az k8s-extension delete \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --resource-group $RG_NAME \
    --name appservice-ext

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
http://40.121.221.220:15672

sqlcmd -S 10.128.1.4 -U reddogadmin -P "nJ0fqrQx7T^NZFl4sFf*U"

export REDISIP="40.121.221.220"
export REDISPWD="MyPassword123"
redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 keys "loyalty*" | xargs redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 DEL
redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 keys "make*" | xargs redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 DEL



```