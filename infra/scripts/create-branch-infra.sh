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
check_for_azure_login
check_for_cloud-shell

#####################################################################
# Start Functions
#####################################################################

# Initialize SQL in the branch cluster
sql_init() {
  # Preconfig SQL DB - Suggest moving this somehow to the Bootstrapper app itself
  run_on_jumpbox "DEBIAN_FRONTEND=noninteractive; curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - ; curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list; sudo apt-get update; sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev;"

  SECONDS="90"
  # Wait 2 minutes for deps to deploy
  echo "[branch: $BRANCH_NAME] - Waiting $SECONDS seconds for Dependencies to deploy before installing base reddog-retail configs" | tee /dev/tty
  sleep $SECONDS 

  echo "[branch: $BRANCH_NAME] - Setup SQL User: $SQL_ADMIN_USER_NAME and DB" | tee /dev/tty

  echo "
  create database reddog;
  go
  use reddog;
  go
  create user $SQL_ADMIN_USER_NAME for login $SQL_ADMIN_USER_NAME;
  go
  create login $SQL_ADMIN_USER_NAME with password = '$SQL_ADMIN_PASSWD';
  go
  grant create table to $SQL_ADMIN_USER_NAME;
  grant control on schema::dbo to $SQL_ADMIN_USER_NAME;
  ALTER SERVER ROLE sysadmin ADD MEMBER $SQL_ADMIN_USER_NAME;
  go" | run_on_jumpbox "cat > temp.sql"
  
  run_on_jumpbox "
    kubectl wait --for=condition=ready pod -l app=mssql  -n sql; \
    /opt/mssql-tools/bin/sqlcmd -S 10.128.1.4 -U SA -P \"$SQL_ADMIN_PASSWD\" -i temp.sql"

  echo "[branch: $BRANCH_NAME] - Done SQL setup" | tee /dev/tty
}

#### Corp Transfer Function
rabbitmq_create_bindings(){
    # Manually create 2 queues/bindings in Rabbit MQ
        run_on_jumpbox "kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq -n rabbitmq;"
        run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD list exchanges;"
        run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD list queues;"
        run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare queue name=corp-transfer-orders durable=true auto_delete=true;"
        run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare binding source=orders destination_type=queue destination=corp-transfer-orders;"
        run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare queue name=corp-transfer-ordercompleted durable=true auto_delete=true;"
        run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare binding source=ordercompleted destination_type=queue destination=corp-transfer-ordercompleted;"
}

ssh_copy_key_to_jumpbox() {
  # Get the jump server public IP
  export JUMP_IP=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .publicIP.value)

  # Copy the private key up to the jump server to be used to access the rest of the nodes
  echo "[branch: $BRANCH_NAME] - Copying private key to jump server ..." | tee /dev/tty
  echo "[branch: $BRANCH_NAME] - Waiting for cloud-init to finish configuring the jumpbox ..." | tee /dev/tty
  
  # try to copy the ssh key to the server. Check if the key is present in the jumpbox before that.
  if ! run_on_jumpbox -- file /home/reddogadmin/.ssh/id_rsa; then
    until scp -P 2022 -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP:~/.ssh/id_rsa
    do
      sleep 5
    done
  fi 
}

# Loop through $BRANCHES (from config.json) and create branches
create_branches() {
  export HUB_RG=$RG_NAME
  export HUB_LOCATION=$RG_LOCATION
  for branch in $BRANCHES
  do
    export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
    export RG_LOCATION=$(echo $branch|jq -r '.location')
    export RG_NAME=$PREFIX-reddog-$BRANCH_NAME-$RG_LOCATION

    # Create log directory
    mkdir -p logs

    # Create Branch

    echo -e "\nWaiting for the $BRANCH_NAME branch creation to complete ..."
    echo "Check the log files in ./logs/$RG_NAME.log for its creation status"
    create_branch > ./logs/$RG_NAME.log 2>&1 &
  done

  # wait for all pids
  wait
}

# Create Branch
create_branch() {
  # Set the Subscriptoin
  az account set --subscription $SUBSCRIPTION_ID

  # Create the Resource Group to deploy the Webinar Environment
  az group create --name $RG_NAME --location $RG_LOCATION

  # Deploy the jump server and K3s cluster
  echo "[branch: $BRANCH_NAME] - Deploying branch office resources ..." | tee /dev/tty

  # Note: Ensure that ExtendedLocation provider is registered for the target subscription  
  # az provider register --namespace Microsoft.ExtendedLocation

  az deployment group create \
    --name $ARM_DEPLOYMENT_NAME \
    --mode Incremental \
    --resource-group $RG_NAME \
    --template-file ./scripts/branch-bicep/deploy.bicep \
    --parameters prefix=$PREFIX$BRANCH_NAME \
    --parameters k3sToken="$K3S_TOKEN" \
    --parameters adminUsername="$ADMIN_USER_NAME" \
    --parameters adminPublicKey="$SSH_PUB_KEY" \
    --parameters currentUserId="$CURRENT_USER_ID" \
    --parameters rabbitmqconnectionstring="amqp://contosoadmin:$RABBIT_MQ_PASSWD@rabbitmq.rabbitmq.svc.cluster.local:5672" \
    --parameters redispassword=$REDIS_PASSWD

  # Save deployment outputs
  mkdir -p outputs
  az deployment group show -g $RG_NAME -n $ARM_DEPLOYMENT_NAME -o json --query properties.outputs | tee /dev/tty "./outputs/$RG_NAME-bicep-outputs.json"

  CLUSTER_IP_ADDRESS=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterIP.value)
  CLUSTER_FQDN=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterFQDN.value)

  # Get the host name for the control host
  JUMP_VM_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .jumpVMName.value)
  echo "Jump Host Name: $JUMP_VM_NAME" 

  echo "[branch: $BRANCH_NAME] - Waiting for jump server to start" | tee /dev/tty
  while [[ "$(az vm list -d -g $RG_NAME -o tsv --query "[?name=='$JUMP_VM_NAME'].powerState")" != "VM running" ]]
  do
  echo "Waiting ..."
    sleep 5
  done
  echo "[branch: $BRANCH_NAME] - Jump Server Running!" | tee /dev/tty

  # Give the VM a few more seconds to become available
  sleep 20

  ssh_copy_key_to_jumpbox

  run_on_jumpbox "echo alias k=kubectl >> ~/.bashrc"
  echo "[branch: $BRANCH_NAME] - Jump Server connection info: ssh $ADMIN_USER_NAME@$JUMP_IP -i $SSH_KEY_PATH/$SSH_KEY_NAME -p 2022" | tee /dev/tty
  
  # Execute setup script on jump server
  # Get the host name for the control host
  CONTROL_HOST_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .controlName.value)
  echo "Control Host Name: $CONTROL_HOST_NAME"
  echo "[branch: $BRANCH_NAME] - Executing setup script on jump server ..." | tee /dev/tty
  run_on_jumpbox "curl -sfL https://raw.githubusercontent.com/swgriffith/azure-guides/master/temp/get-kube-config.sh |CONTROL_HOST=$CONTROL_HOST_NAME sh -"
  # # Needed to temp fix the file permissions on the kubeconfig file - arc agent install checks the permissions and doesn't like previous 744
  # run_on_jumpbox "curl -sfL https://gist.githubusercontent.com/raykao/1b22f8a807eeda584137ac944c1ea2b9/raw/9d3bc2c52f268e202f708d0645b91f9fc768795e/get-kube-config.sh |CONTROL_HOST=$CONTROL_HOST_NAME sh -"

  # Deploy initial cluster resources
  echo "[branch: $BRANCH_NAME] - Creating Namespaces ..." | tee /dev/tty
  run_on_jumpbox "kubectl create ns reddog-retail;kubectl create ns rabbitmq;kubectl create ns redis;kubectl create ns dapr-system"

  # Create branch config secrets
  echo "[branch: $BRANCH_NAME] - Creating branch config secrets" | tee /dev/tty
  # Do not use Dapr
  # run_on_jumpbox "kubectl create secret generic -n reddog-retail branch.config --from-literal=store_id=$BRANCH_NAME --from-literal=makeline_base_url=http://$CLUSTER_IP_ADDRESS:8082 --from-literal=accounting_base_url=http://$CLUSTER_IP_ADDRESS:8083"
  # Use Dapr inside the UI pod
  run_on_jumpbox "kubectl create secret generic -n reddog-retail branch.config --from-literal=store_id=$BRANCH_NAME --from-literal=makeline_base_url=http://localhost:3500/v1.0/invoke/make-line-service/method --from-literal=accounting_base_url=http://localhost:3500/v1.0/invoke/accounting-service/method"

  echo "[branch: $BRANCH_NAME] - Creating RabbitMQ and Redis Password Secrets ..." | tee /dev/tty
  run_on_jumpbox "kubectl create secret generic rabbitmq-password --from-literal=rabbitmq-password=$RABBIT_MQ_PASSWD -n rabbitmq"
  run_on_jumpbox "kubectl create secret generic redis-password --from-literal=redis-password=$REDIS_PASSWD -n redis"

  # Arc join the cluster
  # Get managed identity object id
  MI_BASENAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .keyvaultName.value | sed 's/-kv.*//g')
  MI_SUFFIX="branchManagedIdentity"
  MI_APP_ID=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .userAssignedMIAppID.value)
  #MI_OBJ_ID=$(az ad sp show --id $MI_APP_ID -o tsv --query objectId)
  MI_OBJ_ID=$(az  identity show -n ${MI_BASENAME}${MI_SUFFIX} -g $RG_NAME -o json| jq -r .principalId)
  echo "User Assigned Managed Identity App ID: $MI_APP_ID"
  echo "User Assigned Managed Identity Object ID: $MI_OBJ_ID"

  echo "[branch: $BRANCH_NAME] - Arc joining the branch cluster ..." | tee /dev/tty
  ARC_CLUSTER_NAME=$PREFIX$BRANCH_NAME-arc
  run_on_jumpbox "az connectedk8s connect -g $RG_NAME -n $ARC_CLUSTER_NAME --distribution k3s --infrastructure generic --custom-locations-oid $MI_OBJ_ID"

  # Key Vault dependencies
  kv_init

  # copy pfx file to jump box and create secret there
  scp -P 2022 -i $SSH_KEY_PATH/$SSH_KEY_NAME $SSH_KEY_PATH/kv-$RG_NAME-cert.pfx $ADMIN_USER_NAME@$JUMP_IP:~/kv-$RG_NAME-cert.pfx
  
  # Get SP APP ID
  echo "Getting SP_APPID ..."
  SP_INFO=$(az ad sp list -o json --display-name "http://sp-$RG_NAME.microsoft.com")
  SP_APPID=$(echo $SP_INFO | jq -r .[].appId)
  echo "AKV SP_APPID: $SP_APPID"

  # Set k8s secret from jumpbox
  run_on_jumpbox "kubectl create secret generic -n reddog-retail reddog.secretstore --from-file=secretstore-cert=kv-$RG_NAME-cert.pfx --from-literal=vaultName=$KV_NAME --from-literal=spnClientId=$SP_APPID --from-literal=spnTenantId=$TENANT_ID"

  # Initial GitOps configuration
  #gitops_configuration_create
  gitops_dependency_create
  
  # Deploy SQL on Arc
  deploy_sql_arc

  # Initialize Dapr in the cluster
  echo "[branch: $BRANCH_NAME] - Deploying Dapr and the reddog app configs ..." | tee /dev/tty
  #dapr_init
  gitops_reddog_create

  # Deploy App Service on Arc
  deploy_appsvc_arc

  echo "[branch: $BRANCH_NAME] - Deploy the corp transfer function" | tee /dev/tty
  FUNC_NAME=$PREFIX$BRANCH_NAME-func-corp-xfer
  FUNC_STOR_ACC=$PREFIX$BRANCH_NAME\funcstor
  SB_CONN=$(az servicebus namespace authorization-rule keys list -g $HUB_RG --namespace-name $PREFIX-hub-servicebus-$HUB_LOCATION -n "RootManageSharedAccessKey" --query "primaryConnectionString" -o tsv)
  MQ_CONN=amqp://contosoadmin:$RABBIT_MQ_PASSWD@rabbitmq.rabbitmq.svc.cluster.local:5672  
  az storage account create -n $FUNC_STOR_ACC -g $RG_NAME --sku Standard_LRS
  az functionapp create -g $RG_NAME -p $APP_SVC_PLAN_NAME -n $FUNC_NAME -s $FUNC_STOR_ACC --functions-version 3 --custom-location $CUSTOM_LOC_ID --deployment-container-image-name https://ghcr.io/mikelapierre/reddog-code/reddog-retail-corp-transfer-service
  az functionapp config appsettings list -g $RG_NAME -n $FUNC_NAME > settings.json
  jq ". += [{\"name\": \"rabbitMQConnectionAppSetting\", \"value\": \"$MQ_CONN\", \"slotSetting\": false}, {\"name\": \"MyServiceBusConnection\", \"value\": \"$SB_CONN\", \"slotSetting\": false}]" settings.json > settings2.json
  az functionapp config appsettings set -g $RG_NAME -n $FUNC_NAME --settings @settings2.json
  az functionapp config appsettings delete -g $RG_NAME -n $FUNC_NAME --setting-names FUNCTIONS_WORKER_RUNTIME
  rm settings.json settings2.json

  echo "[branch: $BRANCH_NAME] - Create corp transfer queues in RabbitMQ" | tee /dev/tty
  rabbitmq_create_bindings     

  echo "[branch: $BRANCH_NAME] - Adding branch to Corp database" | tee /dev/tty
  run_on_jumpbox "/opt/mssql-tools/bin/sqlcmd -S $PREFIX-hub-sqlserver.database.windows.net -U $SQL_ADMIN_USER_NAME -P $SQL_ADMIN_PASSWD -d reddoghub -Q \"insert into storelocation (storeid, city, stateprovince, postalcode, country, latitude, longitude) values ('$BRANCH_NAME', '$BRANCH_NAME', 'SP', 'PC', 'CT', 1, 1)\""

  read -r -d '' COMPLETE_MESSAGE << EOM
****************************************************
[branch: $BRANCH_NAME] - Deployment Complete! 
Jump server connection info: ssh $ADMIN_USER_NAME@$JUMP_IP -i $SSH_KEY_PATH/$SSH_KEY_NAME -p 2022
Cluster connection info: http://$CLUSTER_IP_ADDRESS:8081 or http://$CLUSTER_FQDN:8081
****************************************************
EOM
 
  echo "$COMPLETE_MESSAGE" | tee /dev/tty
}

# Corp Transfer
corp_transfer_fix_init() {
    # generates the corp-transfer-fx
    #func kubernetes deploy --name corp-transfer-service --javascript --registry ghcr.io/cloudnativegbb/paas-vnext --polling-interval 20 --cooldown-period 300 --dry-run > corp-transfer-fx.yaml
    export JUMP_IP=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .publicIP.value)
    scp -P 2022 -i $SSH_KEY_PATH/$SSH_KEY_NAME $BASEDIR/manifests/corp-transfer-secret.yaml $ADMIN_USER_NAME@$JUMP_IP:~/corp-transfer-secret.yaml
    scp -P 2022 -i $SSH_KEY_PATH/$SSH_KEY_NAME $BASEDIR/manifests/corp-transfer-fx.yaml $ADMIN_USER_NAME@$JUMP_IP:~/corp-transfer-fx.yaml
}

corp_transfer_fix_apply() {
    # Corp Transfer Service Secret (need to run the func deploy and edit to only include secret)
    # we will copy these files to the jumpbox and execute the kubectl locally there
    echo \
    'kubectl apply -f corp-transfer-secret.yaml -n reddog-retail;
    kubectl apply -f corp-transfer-fx.yaml -n reddog-retail'
}

keda_init() {
    # KEDA
    echo \
    'helm repo add kedacore https://kedacore.github.io/charts;
    helm repo update;
    helm install keda kedacore/keda --version 2.0.0 --create-namespace --namespace keda'
}

deploy_sql_arc() {
  echo "[branch: $BRANCH_NAME] - Enable Data Controller Extension" | tee /dev/tty
  az provider register --namespace "Microsoft.AzureArcData" --wait
  DATA_CTRL_EXTN_NAME=$PREFIX$BRANCH_NAME-data
  DATA_CTRL_NS=$PREFIX$BRANCH_NAME-data
  run_on_jumpbox "az k8s-extension create --cluster-name $ARC_CLUSTER_NAME --resource-group $RG_NAME --name $DATA_CTRL_EXTN_NAME --cluster-type connectedClusters --extension-type microsoft.arcdataservices --auto-upgrade false --scope cluster --release-namespace $DATA_CTRL_NS --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper --no-wait"

  echo "[branch: $BRANCH_NAME] - Wait for extension to be provisioned" | tee /dev/tty
  DATA_CTRL_EXT_ID=$(az k8s-extension show \
  --cluster-type connectedClusters \
  --cluster-name $ARC_CLUSTER_NAME \
  --resource-group $RG_NAME \
  --name $DATA_CTRL_EXTN_NAME \
  --query id \
  --output tsv)
  az resource wait --ids $DATA_CTRL_EXT_ID --custom "properties.installState=='Installed'" --api-version "2020-07-01-preview"

  echo "[branch: $BRANCH_NAME] - Assigning permissions to the Data Controller" | tee /dev/tty
  MSI_OBJECT_ID=$(az k8s-extension show \
  --cluster-type connectedClusters \
  --cluster-name $ARC_CLUSTER_NAME \
  --resource-group $RG_NAME \
  --name $DATA_CTRL_EXTN_NAME \
  --query identity.principalId \
  --output tsv)
  az role assignment create --assignee $MSI_OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"
  az role assignment create --assignee $MSI_OBJECT_ID --role "Monitoring Metrics Publisher" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"

  echo "[branch: $BRANCH_NAME] - Create Custom Location for the Data Controller" | tee /dev/tty
  # Enable the feature on the connected cluster 
  ARC_OID=$(az ad sp show --id 'bc313c14-388c-4e7d-a58e-70017303ee3b' --query objectId -o tsv)
  run_on_jumpbox "az connectedk8s enable-features -n $ARC_CLUSTER_NAME -g $RG_NAME --custom-locations-oid $ARC_OID --features cluster-connect custom-locations"
  DATA_CTRL_CUSTOM_LOC_NAME=$PREFIX$BRANCH_NAME-data-cl
  ARC_CLUSTER_ID=$(az connectedk8s show --resource-group $RG_NAME --name $ARC_CLUSTER_NAME --query id --output tsv)
  az customlocation create --resource-group $RG_NAME --name $DATA_CTRL_CUSTOM_LOC_NAME --namespace $DATA_CTRL_NS --host-resource-id $ARC_CLUSTER_ID \
                           --cluster-extension-ids $DATA_CTRL_EXT_ID --location $RG_LOCATION
  DATA_CTRL_CUSTOM_LOC_ID=$(az customlocation show \
    --resource-group $RG_NAME \
    --name $DATA_CTRL_CUSTOM_LOC_NAME \
    --query id \
    --output tsv)  

  echo "[branch: $BRANCH_NAME] - Create the Data Controller" | tee /dev/tty
  DATA_CTRL_NAME=$PREFIX$BRANCH_NAME-data
  export AZDATA_USERNAME=$SQL_ADMIN_USER_NAME
  export AZDATA_PASSWORD=$SQL_ADMIN_PASSWD
  az arcdata dc create --name $DATA_CTRL_NAME --resource-group $RG_NAME --location $RG_LOCATION --connectivity-mode direct \
                       --profile-name "azure-arc-kubeadm" --auto-upload-logs true --auto-upload-metrics true \
                       --custom-location $DATA_CTRL_CUSTOM_LOC_NAME --storage-class "local-path"

  echo "[branch: $BRANCH_NAME] - Create the SQL Managed Instance" | tee /dev/tty
  SQL_MI_NAME=sqlmi # 15 char limit including -0 (13 limit)
  SQL_MI_NS=sqlmi
  az sql mi-arc create --name $SQL_MI_NAME --resource-group $RG_NAME --subscription $SUBSCRIPTION_ID \
                       --custom-location $DATA_CTRL_CUSTOM_LOC_NAME --dev
  SQL_ENDPOINT=$(az sql mi-arc show --name $SQL_MI_NAME --resource-group $RG_NAME --query "properties.k8_s_raw.status.endpoints.primary" -o tsv)

  echo "[branch: $BRANCH_NAME] - Create the SQL database" | tee /dev/tty
  run_on_jumpbox "DEBIAN_FRONTEND=noninteractive; curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - ; curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list; sudo apt-get update; sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev;"
  run_on_jumpbox "/opt/mssql-tools/bin/sqlcmd -S $SQL_ENDPOINT -U $SQL_ADMIN_USER_NAME -P $SQL_ADMIN_PASSWD -Q \"create database reddog\""

  echo "[branch: $BRANCH_NAME] - Set database conneciton string" | tee /dev/tty
  REDDOG_SQL_CONNECTION_STRING="Server=tcp:$SQL_ENDPOINT;Initial Catalog=reddog;Persist Security Info=False;User ID=$SQL_ADMIN_USER_NAME;Password=$SQL_ADMIN_PASSWD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  az keyvault secret set \
      --vault-name $KV_NAME \
      --name reddog-sql \
      --value "${REDDOG_SQL_CONNECTION_STRING}"
}

deploy_appsvc_arc() {
  echo "[branch: $BRANCH_NAME] - Enabling the App Service Arc Extension ..." | tee /dev/tty
  
  echo "[branch: $BRANCH_NAME] - Create Log Analytics Workspace" | tee /dev/tty
  # Setup Arc App Svc Extension
  APP_SVC_LA_WORKSPACE_NAME=$PREFIX$BRANCH_NAME-la
  # Create Workspace
  az monitor log-analytics workspace create \
    --resource-group $RG_NAME \
    --workspace-name $APP_SVC_LA_WORKSPACE_NAME

  # Get Workspace ID and encode
  APP_SVC_LA_ID=$(az monitor log-analytics workspace show \
  --resource-group $RG_NAME \
  --workspace-name $APP_SVC_LA_WORKSPACE_NAME \
  --query customerId --output tsv)

  APP_SVC_LA_ID_ENCODED=$(printf %s $APP_SVC_LA_ID | base64) 

  APP_SVC_LA_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group $RG_NAME \
    --workspace-name $APP_SVC_LA_WORKSPACE_NAME \
    --query primarySharedKey \
    --output tsv)

  APP_SVC_LA_KEY_ENCODED_SPACE=$(printf %s $APP_SVC_LA_KEY | base64)
  APP_SVC_LA_KEY_ENCODED=$(echo -n "${APP_SVC_LA_KEY_ENCODED_SPACE//[[:space:]]/}") 

  echo "[branch: $BRANCH_NAME] - Enable App Service Extension" | tee /dev/tty
  APP_SVC_EXT_NAME=$PREFIX$BRANCH_NAME-appsvc
  # Configure Extension. 
  run_on_jumpbox "
  az k8s-extension create
  --resource-group $RG_NAME
  --name $APP_SVC_EXT_NAME
  --cluster-type connectedClusters
  --cluster-name $ARC_CLUSTER_NAME
  --extension-type 'Microsoft.Web.Appservice'
  --release-train stable
  --auto-upgrade-minor-version true
  --scope cluster
  --release-namespace appservices
  --configuration-settings \"Microsoft.CustomLocation.ServiceAccount=default\"
  --configuration-settings \"appsNamespace=appservices\"
  --configuration-settings \"clusterName=$ARC_CLUSTER_NAME\"
  --configuration-settings \"loadBalancerIp=$CLUSTER_IP_ADDRESS\"
  --configuration-settings \"buildService.storageClassName=local-path\"
  --configuration-settings \"buildService.storageAccessMode=ReadWriteOnce\"
  --configuration-settings \"customConfigMap=appservices/kube-environment-config\"
  --configuration-settings \"logProcessor.appLogs.destination=log-analytics\"
  --configuration-protected-settings \"logProcessor.appLogs.logAnalyticsConfig.customerId=${APP_SVC_LA_ID_ENCODED}\"
  --configuration-protected-settings \"logProcessor.appLogs.logAnalyticsConfig.sharedKey=${APP_SVC_LA_KEY_ENCODED}\"
  --no-wait"

  echo "[branch: $BRANCH_NAME] - Wait for extension to be provisioned" | tee /dev/tty
  APP_SVC_EXT_ID=$(az k8s-extension show \
  --cluster-type connectedClusters \
  --cluster-name $ARC_CLUSTER_NAME \
  --resource-group $RG_NAME \
  --name $APP_SVC_EXT_NAME \
  --query id \
  --output tsv)
  # The Azure Docs recommend waiting until the extension is fully created before proceeding with any additional steps. The below command can help with that.
  az resource wait --ids $APP_SVC_EXT_ID --custom "properties.installState=='Installed'" --api-version "2020-07-01-preview"

  CUSTOM_LOC_NAME=$PREFIX$BRANCH_NAME-appsvc-cl

  echo "[branch: $BRANCH_NAME] - Create Custom Location" | tee /dev/tty
  az customlocation create \
    --resource-group $RG_NAME \
    --name $CUSTOM_LOC_NAME \
    --host-resource-id $ARC_CLUSTER_ID \
    --namespace appservices \
    --cluster-extension-ids $APP_SVC_EXT_ID

  CUSTOM_LOC_ID=$(az customlocation show \
    --resource-group $RG_NAME \
    --name $CUSTOM_LOC_NAME \
    --query id \
    --output tsv)

  echo "[branch: $BRANCH_NAME] - Create App Service environment" | tee /dev/tty
  APP_SVC_ENV_NAME=$PREFIX$BRANCH_NAME-appsvc-env
  az appservice kube create \
    --resource-group $RG_NAME \
    --name $APP_SVC_ENV_NAME \
    --custom-location $CUSTOM_LOC_ID \
    --static-ip $CLUSTER_IP_ADDRESS

  az appservice kube wait -g $RG_NAME -n $APP_SVC_ENV_NAME --created

  echo "[branch: $BRANCH_NAME] - Create App Service plan" | tee /dev/tty      
  APP_SVC_PLAN_NAME=$PREFIX$BRANCH_NAME-appsvc-plan
  az appservice plan create -g $RG_NAME -n $APP_SVC_PLAN_NAME \
    --custom-location $CUSTOM_LOC_ID \
    --per-site-scaling --is-linux --sku K1   
}

#####################################################################
# End Functions
#####################################################################


# If logged in, execute hub resource deployments
if [[ ${AZURE_LOGIN} -eq 1 ]]; then

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

create_branches

fi
