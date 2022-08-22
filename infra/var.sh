#!/usr/bin/env bash

# Set Global Variables
CONFIG="$(cat config.json | jq -r .)"
export CONFIG

ARM_DEPLOYMENT_NAME="reddogbicep"
SUBSCRIPTION_ID="$(echo $CONFIG | jq -r '.subscription_id')"
TENANT_ID="$(echo $CONFIG | jq -r '.tenant_id')"
export ARM_DEPLOYMENT_NAME SUBSCRIPTION_ID TENANT_ID

PREFIX="$(echo $CONFIG | jq -r '.rgNamePrefix')"
export PREFIX

ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.admin_user_name')"
export ADMIN_USER_NAME

SSH_KEY_PATH="./ssh_keys"
SSH_KEY_NAME=$PREFIX"_id_rsa"
export SSH_KEY_PATH SSH_KEY_NAME

SQL_ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.sql_admin_user_name')"
SQL_ADMIN_PASSWD="$(echo $CONFIG | jq -r '.sql_admin_passwd')"
export SQL_ADMIN_USER_NAME SQL_ADMIN_PASSWD

HUBNAME="$(echo $CONFIG | jq -r '.hub.hubName')"
export HUBNAME

RG_LOCATION="$(echo $CONFIG | jq -r '.hub.location')"
RG_NAME=$PREFIX-reddog-$HUBNAME-$RG_LOCATION
export RG_LOCATION RG_NAME

# Branch Variables
BRANCHES="$(echo $CONFIG | jq -c '.branches[]')"
export BRANCHES

K3S_TOKEN="$(echo $CONFIG | jq -r '.k3s_token')"
RABBIT_MQ_PASSWD="$(echo $CONFIG | jq -r '.rabbit_mq_passwd')"
REDIS_PASSWD="$(echo $CONFIG | jq -r '.redis_passwd')"
export K3S_TOKEN RABBIT_MQ_PASSWD REDIS_PASSWD

# Get the current user Object ID
if [[ $AZUREPS_HOST_ENVIRONMENT =~ ^cloud-shell.* ]]; then
	# running in cloud-shell. We can use the information on ACC_OID
	CURRENT_USER_ID=$ACC_OID
else
	# running outside of cloud-shell. We need to retrieve the current user
	CURRENT_USER_ID=$(az ad signed-in-user show | jq -r .id)
fi
export CURRENT_USER_ID

# Set the Subscription
az account set --subscription $SUBSCRIPTION_ID

load_ssh_keys() {
	SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME)"
	SSH_PUB_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME.pub)"
	export SSH_PRIV_KEY SSH_PUB_KEY
}

# Check if the cleanup flag is passed, and ignore the ssh_key step
if [[ ! -k $1 && $1 == "cleanup" ]]
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
		if [ ! -d "$SSH_KEY_PATH" ]
		then
			echo "Creating ssh key directory..."
			mkdir $SSH_KEY_PATH
		fi
		echo "Generating ssh key..."
		ssh-keygen -f $SSH_KEY_PATH/$SSH_KEY_NAME -N ''
		chmod 400 $SSH_KEY_PATH/$SSH_KEY_NAME
		
		load_ssh_keys
	fi
fi
