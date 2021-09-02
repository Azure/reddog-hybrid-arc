## Updated docs for demo setup

#### Branch Setup

> Run Bicep scripts in infra to deploy Corp and Branch first

```bash
export BRANCH_NAME=boulder
export RG_BRANCH=reddog-$BRANCH_NAME
export BRANCH_CLUSTER_NAME=reddog-$BRANCH_NAME
export BRANCH_LOC=eastus
export KV_NAME=reddogboulder

ssh reddogadmin@104.211.49.147 -i ./ssh_keys/id_rsa

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

export BRANCH_NAME=boulder
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
```