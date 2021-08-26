#! /bin/bash

# Set Global Variables
export CONFIG="$(cat demo-config.json | jq -r )"

export ARM_DEPLOYMENT_NAME="reddogbicep"
export SUBSCRIPTION_ID="$(echo $CONFIG | jq -r '.subscription_id')"
export TENANT_ID="$(echo $CONFIG | jq -r '.tenant_id')"

export PREFIX="$(echo $CONFIG | jq -r '.rgNamePrefix')"

export ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.admin_user_name')"

export SSH_KEY_PATH="./ssh_keys"
export SSH_KEY_NAME=$PREFIX"_id_rsa"

export SQL_ADMIN_USER_NAME="$(echo $CONFIG | jq -r '.sql_admin_user_name')"
export SQL_ADMIN_PASSWD="$(echo $CONFIG | jq -r '.sql_admin_passwd')"

export HUBNAME"=$(echo $CONFIG | jq -r '.hub.hubName')"

export RG_LOCATION="$(echo $CONFIG | jq -r '.hub.location')"
export RG_NAME=reddog-$PREFIX-$HUBNAME-$RG_LOCATION

# Branch Variables
export BRANCHES="$(echo $CONFIG | jq -c '.branches[]')"

export K3S_TOKEN="$(echo $CONFIG | jq -r '.k3s_token')"
export RABBIT_MQ_PASSWD="$(echo $CONFIG | jq -r '.rabbit_passwd')"
export REDIS_PASSWD="$(echo $CONFIG | jq -r '.redis_passwd')"


# Generate ssh-key pair
echo "Creating ssh key directory..."
mkdir $SSH_KEY_PATH
echo "Generating ssh key..."
ssh-keygen -f $SSH_KEY_PATH/$SSH_KEY_NAME -N ''
chmod 400 $SSH_KEY_PATH/$SSH_KEY_NAME

export SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME)"
export SSH_PUB_KEY="$(cat $SSH_KEY_PATH/$SSH_KEY_NAME.pub)"

# Get the current user Object ID
export CURRENT_USER_ID=$(az ad signed-in-user show -o json | jq -r .objectId)

# Set the Subscriptoin
az account set --subscription $SUBSCRIPTION_ID
