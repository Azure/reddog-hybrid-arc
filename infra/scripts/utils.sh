#
# Common utils used by both: branch and hub

check_for_azure_login() {
    # run a command against Azure to check if we are logged in already.
    az group list -o table
    # save the return code from above. Anything different than 0 means we need to login
    AZURE_LOGIN=$?

    if [[ ${AZURE_LOGIN} -ne 0 ]]; then
    # not logged in. Initiate login process
        az login --scope https://graph.microsoft.com//.default
        export AZURE_LOGIN
    fi

    trap exit ERR
    # Set the Subscription
    az account set --subscription $SUBSCRIPTION_ID


}

# inherit_exit is available on bash >= 4
if [[ "${BASH_VERSINFO:-0}" -ge 4 ]]; then
        shopt -s inherit_errexit
fi
trap "echo ERROR: Please check the error messages above." ERR

check_dependencies() {
    local _DEP_FLAG _NEEDED

    # check if the dependencies are installed
    _NEEDED="az jq"
    _DEP_FLAG=false

    echo -e "Checking dependencies for the creation of the branches ...\n"
    for i in ${_NEEDED}
    do
        if hash "$i" 2>/dev/null; then
        # do nothing
            :
        else
            echo -e "\t $_ not installed".
            _DEP_FLAG=true
        fi
    done

    if [[ "${_DEP_FLAG}" == "true" ]]; then
        echo -e "\nDependencies missing. Please fix that before proceeding"
        exit 1
    fi
}

check_for_cloud-shell() {
    # in cloud-shell, you need to do az login as a workaround before 
    # creating the service principal below. 
    #
    # Only run this code when the user invokes run.sh from this directory. 
    if [[ $AZUREPS_HOST_ENVIRONMENT =~ ^cloud-shell.* ]]; then
        echo '****************************************************'
        echo ' Please login to Azure before proceeding.'
  	    echo '****************************************************'
        echo ' In cloud-shell, you need to do az login as a workaround before' 
        echo ' creating the service principal below.' 
        echo
        echo ' reference: https://github.com/Azure/azure-cli/issues/11749#issuecomment-570975762'
        az login --scope https://graph.microsoft.com//.default
    fi
    # we are logged in at this point
    AZURE_LOGIN=1
    export AZURE_LOGIN
}

# Execute commands on the remote jump box
run_on_jumpbox () {
    # Get the jump server public IP
    export JUMP_IP=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .publicIP.value)
    ssh -p 2022 -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP $1
}

kv_init() {
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
    local UPN=$(az ad  signed-in-user show  -o json | jq -r '.userPrincipalName')

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
}

kv_add_secrets() {
    KV_NAME=$(jq -r .keyvaultName.value ./outputs/$RG_NAME-bicep-outputs.json)
    echo "adding Key Vault Secrets"

    # Service Bus
    SB_NAME=$(jq -r .serviceBusName.value ./outputs/$RG_NAME-bicep-outputs.json)
    SB_CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list \
        --resource-group $RG_NAME \
        --namespace-name  $SB_NAME \
        --name RootManageSharedAccessKey | jq -r '.primaryConnectionString')

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
}

gitops_dependency_create() {
    
    local _target
    local _manifest_path

    _target=$1

    # checks if we are creating hubs or branches
    if [[ ${_target} == "hub" ]]; then
        _manifest_path="corporate"
        CLUSTER_NAME=$AKS_NAME
    else
        _manifest_path="branch"
        CLUSTER_NAME=$PREFIX$BRANCH_NAME-arc
    fi

    BRANCH=$(git branch --show-current)
    REPO_URL=$(git remote get-url origin)

    az k8s-configuration create --name $RG_NAME-${_target}-deps \
        --cluster-name $CLUSTER_NAME \
        --resource-group $RG_NAME \
        --scope cluster \
        --cluster-type connectedClusters \
        --operator-instance-name flux \
        --operator-namespace flux \
        --operator-params="--git-readonly --git-path=manifests/${_manifest_path}/dependencies --git-branch=$BRANCH --manifest-generation=true" \
        --enable-helm-operator \
        --helm-operator-params='--set helm.versions=v3' \
        --repository-url $REPO_URL
    
    # Checks if dapr is running before proceeding
    #local provisioningState="Pending"
    #while [[ $provisioningState != "Running" ]]; do
    #    #provisioningState=$(az connectedk8s show -n $CLUSTER_NAME -g $RG_NAME -o json | jq -r '.provisioningState')
    #    provisioningState=$(run_on_jumpbox kubectl get pod -n dapr-system -l app=dapr-operator -o jsonpath='{.items[0].status.phase}')
    #    echo "."
    #    sleep 5
    #done
    
    sleep 60
}

gitops_reddog_create() { 
    local _target
    local _manifest_path

    _target=$1

    # checks if we are creating hubs or branches
    if [[ ${_target} == "hub" ]]; then
        _manifest_path="corporate"
        CLUSTER_NAME=$AKS_NAME
    else
        _manifest_path="branch"
        CLUSTER_NAME=$PREFIX$BRANCH_NAME-arc
    fi

    BRANCH=$(git branch --show-current)
    REPO_URL=$(git remote get-url origin)    

    az k8s-configuration create --name $RG_NAME-${_target}-base \
        --cluster-name $CLUSTER_NAME \
        --resource-group $RG_NAME \
        --scope namespace \
        --cluster-type connectedClusters \
        --operator-instance-name base \
        --operator-namespace reddog-retail \
        --operator-params="--git-readonly --git-path=manifests/${_manifest_path}/base --git-branch=$BRANCH --manifest-generation=true" \
        --repository-url $REPO_URL

    # Should check to see if pods are running

}
