#!/usr/bin/env bash
set -u 

# check if all of the required variables are set. if not, exit 1.
check_global_variables() {
    local _global_vars
	_global_vars=(
    	ADMIN_USER_NAME BRANCHES CURRENT_USER_ID K3S_TOKEN PREFIX RABBIT_MQ_PASSWD REDIS_PASSWD 
    	SQL_ADMIN_PASSWD SQL_ADMIN_USER_NAME SUBSCRIPTION_ID TENANT_ID
    )
    
    for var in ${_global_vars[@]} 
    do
        if [[ -z "${!var}"  || "${!var}" == "null" ]]; then
    	    echo "${var} is not set. Please check your config.json"
	    exit 1
	fi
    done
}

# Set and export Variables
CONFIG="$(cat config.json | jq -r .)"
export CONFIG

ARM_DEPLOYMENT_NAME="reddogbicep"
SUBSCRIPTION_ID="$(echo $CONFIG | jq -r '.subscription_id')"
TENANT_ID="$(echo $CONFIG | jq -r '.tenant_id')"
export ARM_DEPLOYMENT_NAME SUBSCRIPTION_ID TENANT_ID

PREFIX="$(echo $CONFIG | jq -r '.rgNamePrefix')"
export PREFIX

ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.admin_user_name')"
SSH_KEY_PATH="./ssh_keys"
SSH_KEY_NAME=$PREFIX"_id_rsa"
export ADMIN_USER_NAME SSH_KEY_NAME SSH_KEY_PATH

BRANCHES="$(echo $CONFIG | jq -c '.branches[]')"
export BRANCHES

K3S_TOKEN="$(echo $CONFIG | jq -r '.k3s_token')"
RABBIT_MQ_PASSWD="$(echo $CONFIG | jq -r '.rabbit_mq_passwd')"
REDIS_PASSWD="$(echo $CONFIG | jq -r '.redis_passwd')"
export K3S_TOKEN RABBIT_MQ_PASSWD REDIS_PASSWD

SQL_ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.sql_admin_user_name')"
SQL_ADMIN_PASSWD="$(echo $CONFIG | jq -r '.sql_admin_passwd')"
export SQL_ADMIN_USER_NAME SQL_ADMIN_PASSWD

# Get the current user Object ID
CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)
export CURRENT_USER_ID

# check if all of the global variables are set before proceeding
check_global_variables

load_ssh_keys() {
	SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME)"
	SSH_PUB_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME.pub)"
	export SSH_PRIV_KEY SSH_PUB_KEY
}

# Check if the cleanup flag is passed, and ignore the ssh_key step
if [[ ${1:-default} == "cleanup" ]]
then
	echo "Running cleanup. Don't generate ssh keys."
else
	# Generate ssh-key pair
	if [ -f "$SSH_KEY_PATH/$SSH_KEY_NAME" ] 
	then
		echo "$SSH_KEY_PATH/$SSH_KEY_NAME exists. Skipping SSH Key Gen"
		load_ssh_keys
	else
		echo "$SSH_KEY_PATH/$SSH_KEY_NAME does not exist...Generating SSH Key"
		echo "Creating ssh key directory..."
		mkdir $SSH_KEY_PATH
		echo "Generating ssh key..."
		ssh-keygen -f $SSH_KEY_PATH/$SSH_KEY_NAME -N ''
		chmod 400 $SSH_KEY_PATH/$SSH_KEY_NAME
		
		load_ssh_keys
	fi
fi

# Set the Subscriptoin
az account set --subscription $SUBSCRIPTION_ID

BICEP_FILE="../deploy.bicep"
export BICEP_FILE
