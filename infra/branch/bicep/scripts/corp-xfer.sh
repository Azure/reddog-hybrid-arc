#!/usr/bin/env bash

BASEDIR=$(pwd | sed 's!infra.*!!g')

source $BASEDIR/infra/common/utils.subr
source $BASEDIR/infra/common/branch.subr

source ./var.sh

# Corp Transfer
corp_transfer_fix_init() {
    # generates the corp-transfer-fx
    #func kubernetes deploy --name corp-transfer-service --javascript --registry ghcr.io/cloudnativegbb/paas-vnext --polling-interval 20 --cooldown-period 300 --dry-run > corp-transfer-fx.yaml

    # Corp Transfer Service Secret (need to run the func deploy and edit to only include secret)
    kubectl apply -f $BASEDIR/manifests/corp-transfer-secret.yaml -n reddog-retail
    kubectl apply -f $BASEDIR/manifests/corp-transfer-fx.yaml -n reddog-retail
}

#### Corp Transfer Function
rabbitmq_create_bindings(){
    # Manually create 2 queues/bindings in Rabbit MQ
    run_on_jumpbox 'rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p MyPassword123 list exchanges; 
        rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p MyPassword123 list queues;
        rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p MyPassword123 declare queue name="corp-transfer-orders" durable=true auto_delete=true;
        rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p MyPassword123 declare binding source="orders" destination_type="queue" destination="corp-transfer-orders";
        rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p MyPassword123 declare queue name="corp-transfer-ordercompleted" durable=true auto_delete=true;
        rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p MyPassword123 declare binding source="ordercompleted" destination_type="queue" destination="corp-transfer-ordercompleted";'
}

show_params() {
  # Set Variables from var.sh
  source ./var.sh
  
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
}

run_on_jumpbox () {
    ssh -p 2022 -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP $1
}

show_params

CLUSTER_IP_ADDRESS=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterIP.value)
CLUSTER_FQDN=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterFQDN.value)

# Get the host name for the control host
JUMP_VM_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .jumpVMName.value)
echo "Jump Host Name: $JUMP_VM_NAME" 

run_on_jumpbox "kubectl get all -n rabbitmq"