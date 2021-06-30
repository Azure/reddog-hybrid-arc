## Contoso Health Demo Setup

https://contoso-corp-dashboard.azurewebsites.net/#/dashboard
https://contoso-denver-dashboard.denver-kube-env-557soegs.eastus.k4apps.io/#/dashboard

#### Arc GitOps

```bash
export BRANCH_NAME=denver
export RG_BRANCH=contoso-health-$BRANCH_NAME
export BRANCH_CLUSTER_NAME=contoso-health-$BRANCH_NAME
export BRANCH_LOC=eastus

Server=tcp:mssql-deployment.sql.svc.cluster.local,1433;Initial Catalog=contoso;Persist Security Info=False;User ID=contosouser;Password=MyPassword123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;

az connectedk8s connect --name $BRANCH_CLUSTER_NAME --resource-group $RG_BRANCH --location $BRANCH_LOC

kubectl create ns contoso-health
kubectl create ns rabbitmq
kubectl create ns redis

k get secret -n rabbitmq rabbitmq -o jsonpath='{.data.rabbitmq-password}' | base64 -d
user
amqp://user:MyPassword123@rabbitmq.rabbitmq.svc.cluster.local:5672

k get secret -n redis redis -o jsonpath='{.data.redis-password}' | base64 -d

kubectl create secret generic -n rabbitmq rabbitmq-password --from-literal=rabbitmq-password=MyPassword123
kubectl create secret generic -n redis redis-password --from-literal=redis-password=MyPassword123
kubectl create secret generic -n contoso-health reddog.secretstore --from-file=secretstore-cert="./kv-denver-cert.pfx" 
kubectl apply -f ./RedDog.CorporateTransferService/func-deployment.yaml -n contoso-health

helm upgrade --install dapr dapr/dapr --version=1.1.2 --namespace dapr-system --create-namespace 

az k8sconfiguration create --name branch-office \
--cluster-name $BRANCH_CLUSTER_NAME \
--resource-group $RG_BRANCH \
--scope cluster \
--cluster-type connectedClusters \
--operator-instance-name flux \
--operator-namespace flux \
--operator-params='--git-readonly --git-path=manifests/branch/denver,manifests/branch/dependencies --git-branch=contoso-health --manifest-generation=true' \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url git@github.com:lynn-orrell/reddog.git \
--ssh-private-key-file /Users/profile/.ssh/gitops

az k8sconfiguration list --cluster-name $BRANCH_CLUSTER_NAME --resource-group $RG_BRANCH --cluster-type connectedClusters

az k8sconfiguration delete --cluster-name $BRANCH_CLUSTER_NAME --resource-group $RG_BRANCH --cluster-type connectedClusters -n branch-office

kubectl get namespace cert-manager -o json > cert-manager.json
kubectl get namespace contoso-health -o json > contoso-health.json
kubectl get namespace keda -o json > keda.json
kubectl get namespace nginx-ingress -o json > nginx-ingress.json
kubectl get namespace rabbitmq -o json > rabbitmq.json
kubectl get namespace redis -o json > redis.json
kubectl get namespace appservice-ns -o json > appservice-ns.json

kubectl replace --raw "/api/v1/namespaces/cert-manager/finalize" -f ./cert-manager.json
kubectl replace --raw "/api/v1/namespaces/contoso-health/finalize" -f ./contoso-health.json
kubectl replace --raw "/api/v1/namespaces/keda/finalize" -f ./keda.json
kubectl replace --raw "/api/v1/namespaces/nginx-ingress/finalize" -f ./nginx-ingress.json
kubectl replace --raw "/api/v1/namespaces/rabbitmq/finalize" -f ./rabbitmq.json
kubectl replace --raw "/api/v1/namespaces/redis/finalize" -f ./redis.json
kubectl replace --raw "/api/v1/namespaces/appservice-ns/finalize" -f ./appservice-ns.json
```

#### Demo Setup

```bash
# Variables
export RG_CORP=reddog-health-corp
export BRANCH_NAME=tampa
export RG_BRANCH=reddog-health-$BRANCH_NAME
export CORP_LOC=eastus
export BRANCH_LOC=eastus
export CORP_CLUSTER_NAME=reddog-health-corp
export BRANCH_CLUSTER_NAME=reddog-health-$BRANCH_NAME
export K8S_VERSION=1.19.11
export NODECOUNT=4
export SERVICE_BUS=sbreddoghealth
export STORAGE_ACCT=reddoghealthreceipts
export COSMOSNAME=reddogcontosohealth
export KV_CORP=reddog-health-kv-corp
export KV_BRANCH=reddog-kv-$BRANCH_NAME
export PASSWORD=MyPassword123

# Resource Groups
az group create -n $RG_CORP -l $CORP_LOC
az group create -n $RG_BRANCH -l $BRANCH_LOC

# Create Corp AKS Cluster
az aks create -g $RG_CORP -n $CORP_CLUSTER_NAME \
--node-count $NODECOUNT \
--enable-managed-identity \
--location $CORP_LOC \
--kubernetes-version $K8S_VERSION

az aks get-credentials -g $RG_CORP -n $CORP_CLUSTER_NAME

# Create Branch AKS Cluster
az aks create -g $RG_BRANCH -n $BRANCH_CLUSTER_NAME \
--node-count $NODECOUNT \
--enable-managed-identity \
--location $BRANCH_LOC \
--kubernetes-version $K8S_VERSION

az aks get-credentials -g $RG_BRANCH -n $BRANCH_CLUSTER_NAME

# Create Branch AKS Cluster (Lima)
az aks create -g $RG_BRANCH -n $BRANCH_CLUSTER_NAME \
--node-count $NODECOUNT \
--enable-managed-identity \
--location $BRANCH_LOC \
--enable-aad \
--kubernetes-version $K8S_VERSION

az aks get-credentials -g $RG_BRANCH -n $BRANCH_CLUSTER_NAME --admin

# Service Bus Corp & Topics
az servicebus namespace create --resource-group $RG_CORP --name $SERVICE_BUS --location $CORP_LOC
az servicebus topic create --resource-group $RG_CORP --namespace-name $SERVICE_BUS --name ordercompleted
az servicebus topic create --resource-group $RG_CORP --namespace-name $SERVICE_BUS --name orders

# Storage Account
az storage account create --name $STORAGE_ACCT \
  --resource-group $RG_CORP \
  --location $CORP_LOC \
  --sku Standard_LRS \
  --kind StorageV2

# Deploy CosmosDB (Corp only)
az cosmosdb create --name $COSMOSNAME --resource-group $RG_CORP

Create DB "reddog"
Create Container "loyalty" partition key /id

# Key Vault 
az keyvault create --name $KV_CORP --resource-group $RG_CORP --location $CORP_LOC
az keyvault create --name $KV_BRANCH --resource-group $RG_BRANCH --location $BRANCH_LOC

# SP & Cert Setup (Branch)
az ad sp create-for-rbac --name "http://sp-reddog-$BRANCH_NAME" --create-cert --cert cert-contoso-$BRANCH_NAME --keyvault $KV_BRANCH --skip-assignment --years 1

export BRANCH_NAME=denver
export SP_APPID=$(az ad sp show --id "http://sp-reddog-$BRANCH_NAME" -o tsv --query "appId")
echo $SP_APPID
export TENANT=""
export SP_OBJECTID=$(az ad sp show --id "http://sp-reddog-$BRANCH_NAME" -o tsv --query "objectId")

az keyvault set-policy --name $KV_BRANCH --object-id $SP_OBJECTID --secret-permissions get
az keyvault secret download --vault-name $KV_BRANCH --name cert-reddog-$BRANCH_NAME --encoding base64 --file kv-$BRANCH_NAME-cert.pfx

# SP & Cert Setup (Corp)
az ad sp create-for-rbac --name "http://sp-reddog-corp" --create-cert --cert cert-contoso-corp --keyvault $KV_CORP --skip-assignment --years 1

export SP_APPID=$(az ad sp show --id "http://sp-reddog-corp" -o tsv --query "appId")
echo $SP_APPID
export TENANT=""
export SP_OBJECTID=$(az ad sp show --id "http://sp-reddog-corp" -o tsv --query "objectId")

az keyvault set-policy --name $KV_CORP --object-id $SP_OBJECTID --secret-permissions get
az keyvault secret download --vault-name $KV_CORP --name cert-reddog-corp --encoding base64 --file kv-corp-cert.pfx

# Manually created Azure SQL Server and SQL DB (Corp and Branch)
# Use reddogadmin for server user 

# Rabbit MQ
helm repo add azure-marketplace https://marketplace.azurecr.io/helm/v1/repo
helm repo update
helm install \
--set replicaCount=3 \
--set service.type=LoadBalancer \
--set auth.username=contosoadmin \
--set auth.password=MyPassword123 \
--set podSecurityContext.enabled=true \
--set podSecurityContext.fsGroup=2000 \
--set podSecurityContext.runAsUser=0 \
--namespace=rabbitmq \
--create-namespace \
rabbitmq azure-marketplace/rabbitmq

helm install --set replicaCount=3 --set service.type=LoadBalancer --set auth.username=contosoadmin --set auth.password=MyPassword123 --set podSecurityContext.enabled=true --set podSecurityContext.fsGroup=2000 --set podSecurityContext.runAsUser=0 --namespace=rabbitmq --create-namespace rabbitmq azure-marketplace/rabbitmq

# Redis (use Redis Insight to browse data)
helm repo add azure-marketplace https://marketplace.azurecr.io/helm/v1/repo
helm repo update
helm install \
--set auth.password=MyPassword123 \
--set master.podSecurityContext.enabled=true \
--set master.podSecurityContext.fsGroup=2000 \
--set master.containerSecurityContext.runAsUser=0 \
--set master.containerSecurityContext.enabled=true \
--set replica.podSecurityContext.enabled=true \
--set replica.podSecurityContext.fsGroup=2000 \
--set replica.containerSecurityContext.runAsUser=0 \
--set replica.containerSecurityContext.enabled=true \
--namespace=redis \
--create-namespace \
redis-cache azure-marketplace/redis

helm install --set auth.password=MyPassword123 --set master.podSecurityContext.enabled=true --set master.podSecurityContext.fsGroup=2000 --set master.containerSecurityContext.runAsUser=0 --set master.containerSecurityContext.enabled=true --set replica.podSecurityContext.enabled=true --set replica.podSecurityContext.fsGroup=2000 --set replica.containerSecurityContext.runAsUser=0 --set replica.containerSecurityContext.enabled=true --namespace=redis --create-namespace redis-cache azure-marketplace/redis

# Zipkin
kubectl create ns zipkin
kubectl create deployment zipkin -n zipkin --image openzipkin/zipkin
kubectl expose deployment zipkin -n zipkin --type LoadBalancer --port 9411

# Dapr Install
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr \
--version=1.1.2 \
--namespace dapr-system \
--create-namespace 

helm upgrade --install dapr dapr/dapr --version=1.1.2 --namespace dapr-system --create-namespace 

# NGINX Ingress
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
helm install nginx nginx-stable/nginx-ingress --set controller.replicaCount=1 --namespace nginx --create-namespace 

# SQL Server on AKS Branch (without Arc)
kubectl create ns sql
kubectl create secret generic mssql --from-literal=SA_PASSWORD="MyPassword123" -n sql
kubectl apply -f ./manifests/sql/pvc.yaml -n sql
kubectl apply -f ./manifests/sql/pvc-hci.yaml -n sql
kubectl apply -f ./manifests/sql/sql-server.yaml -n sql

kubectl delete -f ./manifests/sql/sql-server.yaml -n sql

sqlcmd -S 192.168.1.1 -U sa -P "MyPassword123"

# for SQL Azure
create user contosouser with password = 'MyPassword123';
grant create table to contosouser;
grant control on schema::dbo to contosouser;

# for SQL container on K8s
create login contosouser with password = 'MyPassword123';

ALTER SERVER ROLE sysadmin ADD MEMBER contosouser;

CREATE DATABASE contoso;


# Add secrets in Key Vault manually
redis-password
MyPassword123

reddog-sql
Server=tcp:mssql-deployment.sql.svc.cluster.local,1433;Initial Catalog=contoso;Persist Security Info=False;User ID=contosouser;Password=MyPassword123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;

Server=tcp:contoso-health-corp.database.windows.net,1433;Initial Catalog=contoso-health-corp;Persist Security Info=False;User ID=contosoadmin;Password=MyPassword123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;

Server=tcp:192.168.1.1,1433;Initial Catalog=contoso;Persist Security Info=False;User ID=contosouser;Password=MyPassword123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;

rabbitmq-connectionstring
amqp://contosoadmin:MyPassword123@rabbitmq.rabbitmq.svc.cluster.local:5672
amqp://contosoadmin:MyPassword123@192.168.1.1:5672

blob-storage-key (password only. plan to use local storage eventually)

cosmos-primary-rw-key (for corp)

sb-root-connectionstring (for corp)

# Namespace
kubectl create ns contoso-health

# Corp Transfer Service

# KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --version 2.0.0 --create-namespace --namespace keda

# Manually create 2 queues/bindings in Rabbit MQ
corp-transfer-orders
corp-transfer-ordercompleted

# Corp Transfer Service Secret (need to run the func deploy and edit to only include secret)
kubectl apply -f ./RedDog.CorporateTransferService/func-deployment.yaml -n contoso-health

# Deploy Branch
kubectl create secret generic reddog.secretstore --from-file=secretstore-cert="./kv-denver-cert.pfx" -n contoso-health
kubectl apply -f ./manifests/branch/base/deployments/rbac.yaml

kubectl apply -f ./manifests/branch/base/components/reddog.binding.receipt.yaml
kubectl apply -f ./manifests/branch/base/components/reddog.binding.virtualworker.yaml
kubectl apply -f ./manifests/branch/base/components/reddog.config.yaml
kubectl apply -f ./manifests/branch/base/components/reddog.pubsub.yaml
kubectl apply -f ./manifests/branch/base/components/reddog.secretstore.yaml
kubectl apply -f ./manifests/branch/base/components/reddog.state.loyalty.yaml
kubectl apply -f ./manifests/branch/base/components/reddog.state.makeline.yaml
 
kubectl apply -f ./manifests/branch/base/deployments/bootstrapper.yaml

kubectl apply -f ./manifests/branch/base/deployments/order-service.yaml
kubectl apply -f ./manifests/branch/base/deployments/make-line-service.yaml
kubectl apply -f ./manifests/branch/base/deployments/loyalty-service.yaml
kubectl apply -f ./manifests/branch/base/deployments/receipt-generation-service.yaml
kubectl apply -f ./manifests/branch/base/deployments/accounting-service.yaml

kubectl apply -f ./manifests/branch/base/deployments/virtual-customers.yaml
kubectl apply -f ./manifests/branch/base/deployments/virtual-worker.yaml
kubectl apply -f ./manifests/ui.yaml

kubectl apply -f ./manifests/branch/base/deployments/corp-transfer-fx.yaml

kubectl apply -f ./manifests/ingress.yaml
kubectl apply -f ./manifests/services-for-ui.yaml

kubectl delete -f ./manifests/branch/base/deployments/bootstrapper.yaml
kubectl delete -f ./manifests/branch/base/deployments/order-service.yaml
kubectl delete -f ./manifests/branch/base/deployments/make-line-service.yaml
kubectl delete -f ./manifests/branch/base/deployments/loyalty-service.yaml
kubectl delete -f ./manifests/branch/base/deployments/receipt-generation-service.yaml
kubectl delete -f ./manifests/branch/base/deployments/accounting-service.yaml
kubectl delete -f ./manifests/branch/base/deployments/ui.yaml
kubectl delete -f ./manifests/branch/base/deployments/virtual-customers.yaml
kubectl delete -f ./manifests/branch/base/deployments/virtual-worker.yaml
kubectl delete -f ./manifests/branch/base/deployments/corp-transfer-fx.yaml

# Deploy Corp
# Need to create the database/collection in Cosmos (partition key is /id)
kubectl create ns contoso-health
kubectl create secret generic reddog.secretstore --from-file=secretstore-cert="./kv-corp-cert.pfx" -n contoso-health
kubectl apply -f ./manifests/corporate/deployments/rbac.yaml

kubectl apply -f ./manifests/corporate/components/reddog.config.yaml
kubectl apply -f ./manifests/corporate/components/reddog.pubsub.yaml
kubectl apply -f ./manifests/corporate/components/reddog.secretstore.yaml
kubectl apply -f ./manifests/corporate/components/reddog.state.loyalty.yaml

kubectl apply -f ./manifests/corporate/deployments/bootstrapper.yaml

kubectl apply -f ./manifests/corporate/deployments/loyalty-service.yaml
kubectl apply -f ./manifests/corporate/deployments/accounting-service.yaml

kubectl apply -f ./manifests/corporate/deployments/accounting-service-lb.yaml

kubectl delete -f ./manifests/corporate/deployments/bootstrapper.yaml
kubectl delete -f ./manifests/corporate/deployments/loyalty-service.yaml
kubectl delete -f ./manifests/corporate/deployments/accounting-service.yaml
```

### Azure Stack HCI

AKS on HCI. https://github.com/Azure/aks-hci/blob/main/eval/readme.md 

```bash
Initialize-AksHciNode

New-AksHciCluster -Name contoso-health-newyork -controlPlaneNodeCount 1 -linuxNodeCount 4 -windowsNodeCount 0
Get-AksHciCredential -Name contoso-health-newyork
Get-AksHciCluster
Set-AksHciCluster –Name contoso-health-newyork -linuxNodeCount 5 -windowsNodeCount 0

choco install kubernetes-helm

Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

# k8s API server
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 6443 -InternalIPAddress '192.168.0.151' -InternalPort 6443

# Rabbit MQ
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 15672 -InternalIPAddress '192.168.1.1' -InternalPort 15672
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 5672 -InternalIPAddress '192.168.1.1' -InternalPort 5672

# Redis
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 6379 -InternalIPAddress '192.168.1.1' -InternalPort 6379

export REDISIP="192.168.1.1"
export REDISPWD="MyPassword123"
redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 keys "loyalty*" | xargs redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 DEL
redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 keys "make*" | xargs redis-cli -h $REDISIP -a $REDISPWD --raw -n 0 DEL

redis-cli --user default --pass FilxT1Yasb
redis-cli --user default --pass FilxT1Yasb monitor
redis-cli --user default --pass FilxT1Yasb KEYS * 
redis-cli --user default --pass FilxT1Yasb GET 'KEYNAME'
redis-cli -h $REDISIP -a FilxT1Yasb HGETALL 'make-line-service||Denver'

# SQL
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 1433 -InternalIPAddress '192.168.1.1' -InternalPort 1433

# Nginx (not used with Lima)
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 80 -InternalIPAddress '192.168.1.1' -InternalPort 80

# Makeline
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 5200 -InternalIPAddress '192.168.1.1' -InternalPort 80

# Accounting
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 5700 -InternalIPAddress '192.168.1.1' -InternalPort 80

# Lima
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 80 -InternalIPAddress '192.168.1.1' -InternalPort 80
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 443 -InternalIPAddress '192.168.1.1' -InternalPort 443

# Cleanup
Get-NetNatStaticMapping
Remove-NetNatStaticMapping -NatName "AKSHCINAT" -StaticMappingID 3

--insecure-skip-tls-verify
```


### Arc 

```bash
# Add AKS clusters to Arc
az connectedk8s list -g $RG_CORP

az connectedk8s connect --name $CORP_CLUSTER_NAME --resource-group $RG_CORP --location eastus
```

### Lima

* Need to stop Windows Remote Management Svc to clear up port 443

```bash
# Lima (need updated extension wheel)
az connectedk8s connect --name $BRANCH_CLUSTER_NAME --resource-group $RG_BRANCH --location eastus

infra_rg=$(az aks show --resource-group $RG_BRANCH --name $BRANCH_CLUSTER_NAME --output tsv --query nodeResourceGroup)
az network public-ip create --resource-group $infra_rg --name MyPublicIP --sku STANDARD

staticIp=$(az network public-ip show --resource-group $infra_rg --name MyPublicIP --output tsv --query ipAddress)
staticIp="192.168.1.1" # PIP of HCI VM

extensionName="appservice-ext"
namespace="appservice-ns"
kubeEnvironmentName="newyork-kube-env"

groupName="contoso-health-newyork"
BRANCH_CLUSTER_NAME="contoso-health-newyork"
workspaceName="$groupName-workspace" # Name of the Log Analytics workspace
customLocationGroup="contoso-health-newyork"
customLocationName="contoso-newyork" # Name of the custom location

az monitor log-analytics workspace create \
    --resource-group $groupName \
    --workspace-name $workspaceName

logAnalyticsWorkspaceId=$(az monitor log-analytics workspace show \
    --resource-group $groupName \
    --workspace-name $workspaceName \
    --query customerId \
    --output tsv)
logAnalyticsWorkspaceIdEnc=$(printf %s $logAnalyticsWorkspaceId | base64) # Needed for the next step
logAnalyticsKey=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group $groupName \
    --workspace-name $workspaceName \
    --query primarySharedKey \
    --output tsv)
logAnalyticsKeyEncWithSpace=$(printf %s $logAnalyticsKey | base64)
logAnalyticsKeyEnc=$(echo -n "${logAnalyticsKeyEncWithSpace//[[:space:]]/}") # Needed for the next step    

az k8s-extension create \
    --resource-group $groupName \
    --name $extensionName \
    --cluster-type connectedClusters \
    --cluster-name $BRANCH_CLUSTER_NAME \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace $namespace \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=${namespace}" \
    --configuration-settings "clusterName=${kubeEnvironmentName}" \
    --configuration-settings "loadBalancerIp=${staticIp}" \
    --configuration-settings "keda.enabled=false" \
    --configuration-settings "buildService.storageClassName=default" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=${namespace}/kube-environment-config" \
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=${aksClusterGroupName}"


    --configuration-settings "logProcessor.appLogs.destination=log-analytics" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${logAnalyticsWorkspaceIdEnc}" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${logAnalyticsKeyEnc}"

extensionId=$(az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $BRANCH_CLUSTER_NAME \
    --resource-group $groupName \
    --name $extensionName \
    --query id \
    --output tsv)

az k8s-extension list --cluster-type connectedClusters --cluster-name $BRANCH_CLUSTER_NAME --resource-group $groupName
az k8s-extension delete -n appservice-ext --cluster-type connectedClusters --cluster-name $BRANCH_CLUSTER_NAME --resource-group $groupName

az resource wait --ids $extensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"

connectedClusterId=$(az connectedk8s show --resource-group $groupName --name $BRANCH_CLUSTER_NAME --query id --output tsv)

az customlocation create \
    --resource-group $groupName \
    --name $customLocationName \
    --host-resource-id $connectedClusterId \
    --namespace $namespace \
    --cluster-extension-ids $extensionId

export customLocationId=$(az customlocation show --resource-group $groupName --name $customLocationName --query id --output tsv)

az appservice kube create \
    --resource-group $groupName \
    --name $kubeEnvironmentName \
    --custom-location $customLocationId \
    --static-ip $staticIp

az appservice kube show \
    --resource-group $groupName \
    --name $kubeEnvironmentName

# web app
https://docs.microsoft.com/en-us/azure/app-service/quickstart-arc

customLocationGroup="contoso-health-denver"
customLocationName="contoso-denver"
appName="contoso-denver-dashboard"
customLocationId=$(az customlocation show --resource-group $customLocationGroup --name $customLocationName --query id --output tsv)

az webapp create --resource-group $customLocationGroup --name $appName --custom-location $customLocationId --runtime 'NODE|12-lts' 

# config settings
az webapp config set --resource-group $customLocationGroup --name $appName --startup-file "npm i @vue/cli-service && npm run container"
az webapp config appsettings set --name $appName --resource-group $customLocationGroup --settings PRE_BUILD_COMMAND="npm run build"
az webapp config appsettings set --name $appName --resource-group $customLocationGroup --settings POST_BUILD_COMMAND="npm run serve"

az webapp config appsettings set --name $appName --resource-group $customLocationGroup --settings PRE_BUILD_COMMAND="npm run build" POST_BUILD_COMMAND="npm run serve" NODE_ENV="production" VUE_APP_IS_CORP="false" VUE_APP_STORE_ID="Denver" VUE_APP_SITE_TYPE="Pharmacy" VUE_APP_SITE_TITLE="Contoso Health :: Chicago" VUE_APP_MAKELINE_BASE_URL="http://192.168.1.1:5200" VUE_APP_ACCOUNTING_BASE_URL="http://192.168.1.1:5700"

# zip deploy
zip -r ../ui.zip .
az webapp deployment source config-zip --resource-group $customLocationGroup --name $appName --src ui.zip

# status
az webapp deployment source show --resource-group $customLocationGroup --name $appName

# web app container
az webapp create --resource-group $customLocationGroup --name $appName --custom-location $customLocationId --runtime 'NODE|12-lts' 

az webapp config appsettings set --name $appName --resource-group $customLocationGroup --settings NODE_ENV="production" VUE_APP_IS_CORP="false" VUE_APP_STORE_ID="Denver" VUE_APP_SITE_TYPE="Pharmacy" VUE_APP_SITE_TITLE="Contoso Health :: Denver" VUE_APP_MAKELINE_BASE_URL="http://192.168.1.1:5200" VUE_APP_ACCOUNTING_BASE_URL="http://192.168.1.1:5700"

az webapp config container set --resource-group $customLocationGroup --name $appName --docker-custom-image-name ghcr.io/cloudnativegbb/paas-vnext/reddog-ui:737c3e2

az webapp delete --resource-group $customLocationGroup --name $appName

NODE_ENV="production" 
VUE_APP_IS_CORP="true" 
VUE_APP_STORE_ID="Corp" 
VUE_APP_SITE_TYPE="Pharmacy" 
VUE_APP_SITE_TITLE="Contoso Health :: Corp"
VUE_APP_MAKELINE_BASE_URL="http://hub.makeline.brianredmond.io" 
VUE_APP_ACCOUNTING_BASE_URL="http://hub.accounting.brianredmond.io"

# Function App
customLocationGroup="contoso-health-denver"
customLocationName="contoso-denver"
customLocationId=$(az customlocation show --resource-group $customLocationGroup --name $customLocationName --query id --output tsv)
storageAccount="contosodenverfx"
functionAppName="contosodenverfx"

az storage account create --name $storageAccount --location eastus --resource-group $customLocationGroup --sku Standard_LRS

az functionapp create --resource-group $customLocationGroup --name $functionAppName --custom-location $customLocationId --storage-account $storageAccount --functions-version 3 --runtime node --runtime-version 12

az functionapp config appsettings set --name $appName --resource-group $customLocationGroup --settings

rabbitMQConnectionAppSetting="amqp://user:MyPassword123@192.168.1.1:5672" 

MyServiceBusConnection=""

# func CLI publish
func azure functionapp publish $functionAppName

# fx zip publish
PUBLISH_FILE_PATH=../fx-publish.zip
zip -r $PUBLISH_FILE_PATH .
SCM_URI=`az functionapp deployment list-publishing-credentials -g $customLocationGroup -n $functionAppName -o tsv --query scmUri`
curl -X POST --data-binary @$PUBLISH_FILE_PATH $SCM_URI/api/zipdeploy
FUNCTION_HOST=$(az functionapp show  -g $MyResourceGroup -n AppName --query "hostNames[0]" -o tsv)

```

### Arc Kubernetes Extensions

```bash
# Create Log Analytics 
az monitor log-analytics workspace create -g $RG -n $AZUREMONITORNAME
export RG=contoso-health-austin
export AZUREMONITORNAME=contoso-health-monitor
export CLUSTERNAME=contoso-health-austin

AZUREMONITOR=$(az monitor log-analytics workspace show -g contoso-health-corp -n $AZUREMONITORNAME -o tsv --query "id")
echo $AZUREMONITOR

az k8s-extension list -g $RG -c $CLUSTERNAME --cluster-type connectedClusters 

# Azure Monitor Extension
az k8s-extension create --cluster-name $CLUSTERNAME --resource-group $RG --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --name azuremonitor-containers --configuration-settings logAnalyticsWorkspaceResourceID=$AZUREMONITOR

# Azure Defender Extension
az k8s-extension create \
  --cluster-type connectedClusters \
  --cluster-name $CLUSTERNAME \
  --resource-group $RG \
  --extension-type microsoft.azuredefender.kubernetes \
  --name microsoft.azuredefender.kubernetes 

# Policy Extension
https://github.com/Azure/azure-arc-kubernetes-preview/blob/master/docs/k8s-extensions-azure-policy.md
az k8s-extension-private create \
  --cluster-type connectedClusters \
  --cluster-name $CLUSTERNAME \
  --resource-group $RG \
  --extension-type Microsoft.PolicyInsights \
  --scope cluster \
  --release-train preview \
  --name azure-policy

# OSM
export VERSION=0.8.4
az k8s-extension create \
--cluster-name $CLUSTERNAME \
--resource-group $RG \
--cluster-type connectedClusters \
--extension-type Microsoft.openservicemesh \
--scope cluster \
--release-train pilot \
--name osm \
--version $VERSION

```

### Arc Enabled Data Services

```bash
# manual mode
kubectl create namespace arc-data
kubectl create --namespace arc-data -f https://raw.githubusercontent.com/microsoft/azure_arc/main/arc_data_services/deploy/yaml/bootstrapper.yaml

echo -n 'contosoadmin' | base64
echo -n 'contosouser' | base64
echo -n 'MyPassword123' | base64

kubectl create --namespace arc-data -f ./manifests/branch/dependencies/sql/controller-login-secret.yaml
kubectl create --namespace arc-data -f ./manifests/branch/dependencies/sql/data-controller.yaml

# sql mi
kubectl create --namespace sql -f ./manifests/branch/dependencies/sql/sql.yaml

# k8s extension (direct mode)

export subscription=
export resourceGroup=contoso-health-corp
export resourceName=contoso-health-newyork
export location=eastus
export ADSExtensionName=data-services-ext

az k8s-extension create -c ${resourceName} -g ${resourceGroup} --name ${ADSExtensionName} --cluster-type connectedClusters --extension-type microsoft.arcdataservices --auto-upgrade false --scope cluster --release-namespace sql --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

az k8s-extension show -g ${resourceGroup} -c ${resourceName} --name ${ADSExtensionName} --cluster-type connectedclusters

export clName=contoso-newyork
export clNamespace=sql
export hostClusterId=$(az connectedk8s show -g ${resourceGroup} -n ${resourceName} --query id -o tsv)
export extensionId=$(az k8s-extension show -g ${resourceGroup} -c ${resourceName} --cluster-type connectedClusters --name ${ADSExtensionName} --query id -o tsv)

az customlocation create -g ${resourceGroup} -n ${clName} --namespace ${clNamespace} \
  --host-resource-id ${hostClusterId} \
  --cluster-extension-ids ${extensionId} --location eastus
```

> Finish creating the data controller in the portal. https://docs.microsoft.com/en-us/azure/azure-arc/data/deploy-data-controller-direct-mode

