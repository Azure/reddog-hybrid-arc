#!/usr/bin/env bash
set -e

# Set Variables
export CONFIG="$(cat config.json | jq -r .)"

export ARM_DEPLOYMENT_NAME="reddogbicep"
export SUBSCRIPTION_ID="$(echo $CONFIG | jq -r '.subscription_id')"
export TENANT_ID="$(echo $CONFIG | jq -r '.tenant_id')"

export PREFIX="$(echo $CONFIG | jq -r '.rgNamePrefix')"

export ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.admin_user_name')"

export SSH_KEY_PATH="./ssh_keys"
export SSH_KEY_NAME=$PREFIX"_id_rsa"

export SQL_ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.sql_admin_user_name')"
export SQL_ADMIN_PASSWD="$(echo $CONFIG | jq -r '.sql_admin_passwd')"

export HUBNAME="$(echo $CONFIG | jq -r '.hub.hubName')"

export RG_LOCATION="$(echo $CONFIG | jq -r '.hub.location')"
export RG_NAME=$PREFIX-reddog-$HUBNAME-$RG_LOCATION

# Check if the cleanup flag is passed, and ignore the ssh_key step
if [[ ! -k $1 && $1 == "cleanup" ]]
then
	echo "Running cleanup. Don't generate ssh keys."
else
	# Generate ssh-key pair
	if [ -f "$SSH_KEY_PATH/$SSH_KEY_NAME" ] 
	then
		echo "$SSH_KEY_PATH/$SSH_KEY_NAME exists. Skipping SSH Key Gen"
	else
		echo "$SSH_KEY_PATH/$SSH_KEY_NAME does not exist...Generating SSH Key"
		echo "Creating ssh key directory..."
		mkdir $SSH_KEY_PATH
		echo "Generating ssh key..."
		ssh-keygen -f $SSH_KEY_PATH/$SSH_KEY_NAME -N ''
		chmod 400 $SSH_KEY_PATH/$SSH_KEY_NAME

	fi
fi

export SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME)"
export SSH_PUB_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME.pub)"
# Get the current user Object ID
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)

# Set the Subscriptoin
az account set --subscription $SUBSCRIPTION_ID

export BICEP_FILE="../deploy.bicep"
