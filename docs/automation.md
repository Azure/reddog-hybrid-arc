## Updated docs for demo setup

#### Branch Setup

> Run Bicep scripts in infra to deploy Corp and Branch first

```bash
export BRANCH_NAME=vail
export RG_BRANCH=reddog-$BRANCH_NAME
export BRANCH_CLUSTER_NAME=reddog-$BRANCH_NAME
export BRANCH_LOC=eastus
export KV_NAME=hub-kv-qfmva3vgu4w6q

ssh reddogadmin@13.82.173.184 -i /Users/brianredmond/source/reddog-retail-demo/infra/branch/bicep/scripts/ssh_keys/brian_id_rsa

scp -r -i /Users/brianredmond/source/reddog-retail-demo/infra/branch/bicep/scripts/ssh_keys/brian_id_rsa /Users/brianredmond/source/reddog-retail-demo/manifests/ reddogadmin@13.82.173.184:~

# on jumpbox
kubectl create ns reddog-retail
kubectl create ns rabbitmq
kubectl create ns redis

kubectl create secret generic -n rabbitmq rabbitmq-password --from-literal=rabbitmq-password=MyPassword123
kubectl create secret generic -n redis redis-password --from-literal=redis-password=MyPassword123

# local machine
az ad sp create-for-rbac --name "http://sp-reddog-$BRANCH_NAME.microsoft.com" --create-cert --cert cert-reddog-$BRANCH_NAME --keyvault $KV_NAME --skip-assignment --years 1

export SP_APPID=$(az ad sp show --id "http://sp-reddog-$BRANCH_NAME.microsoft.com" -o tsv --query "appId")
echo $SP_APPID
export TENANT="72f988bf-86f1-41af-91ab-2d7cd011db47"
export SP_OBJECTID=$(az ad sp show --id "http://sp-reddog-$BRANCH_NAME.microsoft.com" -o tsv --query "objectId")
echo $SP_OBJECTID

az keyvault set-policy --name $KV_NAME --object-id $SP_OBJECTID --secret-permissions get
az keyvault secret download --vault-name $KV_NAME --name cert-reddog-$BRANCH_NAME --encoding base64 --file kv-$BRANCH_NAME-cert.pfx

# copy pfx file to jump box and create secret there
scp -i ./ssh_keys/id_rsa /Users/brianredmond/source/reddog-retail-demo/kv-$BRANCH_NAME-cert.pfx reddogadmin@104.211.49.147:./kv-$BRANCH_NAME-cert.pfx

export BRANCH_NAME=vail
kubectl create secret generic -n reddog-retail reddog.secretstore --from-file=secretstore-cert="./kv-$BRANCH_NAME-cert.pfx" 

# gitops for dependencies
ssh-keygen -t ed25519 -C "briar@microsoft.com" # use as deploy key for private repo

az k8sconfiguration create --name branch-office \
--cluster-name boulder-branch \
--resource-group reddog-boulder-eastus \
--scope cluster \
--cluster-type connectedClusters \
--operator-instance-name flux \
--operator-namespace flux \
--operator-params='--git-readonly --git-path=manifests/branch/dependencies --git-branch=main --manifest-generation=true' \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url git@github.com:Azure/reddog-retail-demo.git \
--ssh-private-key-file /Users/brianredmond/.ssh/gitops2


# Redis (use Redis Insight to browse data)
helm repo add azure-marketplace https://marketplace.azurecr.io/helm/v1/repo
helm repo update

helm install \
--set auth.existingSecret=redis-password \
--set auth.existingSecretPasswordKey=redis-password \
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

sudo apt install redis-tools  

export REDIS_PASSWORD=$(kubectl get secret --namespace redis redis-password -o jsonpath="{.data.redis-password}" | base64 --decode)

kubectl port-forward --namespace redis svc/redis-cache-master 6379:6379 && redis-cli -h 127.0.0.1 -p 6379 -a $REDIS_PASSWORD

export REDIS_PASSWORD=MyPassword123
redis-cli -h 127.0.0.1 -p 6379 -a $REDIS_PASSWORD

# Rabbit MQ
> user name is defaulted to "user"

helm install \
--set auth.existingPasswordSecret=rabbitmq-password \
--set podSecurityContext.enabled=true \
--set podSecurityContext.fsGroup=2000 \
--set podSecurityContext.runAsUser=0 \
--namespace=rabbitmq \
--create-namespace \
rabbitmq azure-marketplace/rabbitmq

--set service.type=LoadBalancer \
--set replicaCount=3 \

Credentials:
    echo "Username      : user"
    echo "Password      : $(kubectl get secret --namespace rabbitmq rabbitmq-password -o jsonpath="{.data.rabbitmq-password}" | base64 --decode)"
    echo "ErLang Cookie : $(kubectl get secret --namespace rabbitmq rabbitmq -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 --decode)"

To Access the RabbitMQ AMQP port:

    echo "URL : amqp://127.0.0.1:5672/"
    kubectl port-forward --namespace rabbitmq svc/rabbitmq 5672:5672

To Access the RabbitMQ Management interface:

    echo "URL : http://127.0.0.1:15672/"
    kubectl port-forward --namespace rabbitmq svc/rabbitmq 15672:15672


helm install \
--set auth.existingPasswordSecret=rabbitmq-password \
--set persistence.enabled=false \
--namespace=rabbitmq \
--create-namespace \
rabbitmq azure-marketplace/rabbitmq


# SQL Server on AKS Branch (without Arc)
kubectl create ns sql
kubectl create secret generic mssql --from-literal=SA_PASSWORD="MyPassword123" -n sql
kubectl apply -f pvc.yaml -n sql
kubectl apply -f sql.yaml -n sql
https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver15

sqlcmd -S 10.128.1.4 -U sa -P "MyPassword123"

create user reddoguser with password = 'MyPassword123';
grant create table to reddoguser;
grant control on schema::dbo to reddoguser;
create login reddoguser with password = 'MyPassword123';
ALTER SERVER ROLE sysadmin ADD MEMBER reddoguser;
CREATE DATABASE reddog;

# KV Secrets
reddog-sql
Server=tcp:mssql-deployment.sql.svc.cluster.local,1433;Initial Catalog=reddog;Persist Security Info=False;User ID=reddoguser;Password=MyPassword123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;

Server=tcp:brian-hub-sqlserver.database.windows.net,1433;Initial Catalog=reddog-retail;Persist Security Info=False;User ID=reddogadmin;Password=nJ0fqrQx7T^NZFl4sFf*U;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;

Server=tcp:brian-hub-sqlserver.database.windows.net,1433;Initial Catalog=reddog-corp;Persist Security Info=False;User ID=reddogadmin;Password={your_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;

redis-password
MyPassword123

blob-storage-key (password only. plan to use local storage eventually)
KYVHapJkUVU/jf9KP0F4p5GatBPgR9NY71f63PStBxq9pUEjiM8kItJn4VoFPrIjhcPU++BKAURecbV6vpVz5w==

cosmos-primary-rw-key (for corp)
nbQ7nNHngaipTtydusSXgdPqn6etHgXkxZYc6MTmAiUBkFK1zcdd6JnxWt5ncUZ5THmSTPbMlBmeg0voPNgz9Q==

sb-root-connectionstring (for corp)
Endpoint=sb://brian-hub-servicebus-eastus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GqOclStVEq7XteEGOtd4VZd3zovAOesPEeLzXUAgwqI=

rabbitmq-connectionstring
amqp://user:MyPassword123@rabbitmq.rabbitmq.svc.cluster.local:5672

make-line-service.reddog-retail.svc.cluster.local
accounting-service.svc.cluster.local

# Corp
export RG_CORP=brian-reddog-hub-eastus
export CORP_LOC=eastus
export KV_CORP=brian-reddog-hub-kvcorp

az keyvault create --name $KV_CORP --resource-group $RG_CORP --location $CORP_LOC

az ad sp create-for-rbac --name "http://sp-reddog3-corp.microsoft.com" --create-cert --cert cert-reddog-retail --keyvault $KV_CORP --skip-assignment --years 1

export SP_APPID=$(az ad sp show --id "http://sp-reddog3-corp.microsoft.com" -o tsv --query "appId")
echo $SP_APPID
export TENANT="72f988bf-86f1-41af-91ab-2d7cd011db47"
export SP_OBJECTID=$(az ad sp show --id "http://sp-reddog3-corp.microsoft.com" -o tsv --query "objectId")
echo $SP_OBJECTID

az keyvault set-policy --name $KV_CORP --object-id $SP_OBJECTID --secret-permissions get
az keyvault secret download --vault-name $KV_CORP --name cert-reddog-retail --encoding base64 --file kv-corp-cert.pfx

kubectl create secret generic reddog.secretstore --from-file=secretstore-cert="./kv-corp-cert.pfx" -n reddog-retail

kubectl apply -f ./manifests/corporate/deployments/rbac.yaml

kubectl apply -f ./manifests/corporate/components/reddog.config.yaml
kubectl apply -f ./manifests/corporate/components/reddog.pubsub.yaml
kubectl apply -f ./manifests/corporate/components/reddog.secretstore.yaml
kubectl apply -f ./manifests/corporate/components/reddog.state.loyalty.yaml

kubectl apply -f ./manifests/corporate/deployments/bootstrapper.yaml

kubectl apply -f ./manifests/corporate/deployments/loyalty-service.yaml
kubectl apply -f ./manifests/corporate/deployments/accounting-service.yaml


```