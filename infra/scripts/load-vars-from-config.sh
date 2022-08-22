#!/usr/bin/env bash

# Set Global Variables
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

# Branch Variables
export BRANCHES="$(echo $CONFIG | jq -c '.branches[]')"
export K3S_TOKEN="$(echo $CONFIG | jq -r '.k3s_token')"
export RABBIT_MQ_PASSWD="$(echo $CONFIG | jq -r '.rabbit_mq_passwd')"
export REDIS_PASSWD="$(echo $CONFIG | jq -r '.redis_passwd')"

# Get the current user Object ID
if [[ $AZUREPS_HOST_ENVIRONMENT =~ ^cloud-shell.* ]]; then
	# running in cloud-shell. We can use the information on ACC_OID
	export CURRENT_USER_ID=$ACC_OID
else
	# running outside of cloud-shell. We need to retrieve the current user
	export CURRENT_USER_ID=$(az ad signed-in-user show -o json| jq -r .id)
fi


echo "Parameters"
echo "------------------------------------------------"
echo "ARM_DEPLOYMENT_NAME: $ARM_DEPLOYMENT_NAME"
echo "SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"
echo "PREFIX: $PREFIX"
echo "ADMIN_USER_NAME: $ADMIN_USER_NAME"
echo "SSH_KEY_PATH: $SSH_KEY_PATH"
echo "SSH_KEY_NAME: $SSH_KEY_NAME"
echo "SQL_ADMIN_USER_NAME: $SQL_ADMIN_USER_NAME"
echo "SQL_ADMIN_PASSWD: $SQL_ADMIN_PASSWD"
echo "HUBNAME: $HUBNAME"
echo "RG_LOCATION: $RG_LOCATION"
echo "RG_NAME: $RG_NAME"
echo "K3S_TOKEN: $K3S_TOKEN"
echo "RABBIT_MQ_PASSWD: $RABBIT_MQ_PASSWD"
echo "REDIS_PASSWD: $REDIS_PASSWD"
echo "CURRENT_USER_ID: $CURRENT_USER_ID"
echo "------------------------------------------------"