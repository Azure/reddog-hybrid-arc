#!/usr/bin/env bash
#set -x

BASEDIR=$(pwd | sed 's!infra.*!!g')

source $BASEDIR/infra/common/utils.subr
source $BASEDIR/infra/common/branch.subr

source ./var.sh

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
  echo "RABBIT_MQ_PASSWD: $RABBIT_MQ_PASSWD"
  echo "------------------------------------------------"
}

run_on_jumpbox () {
    ssh -p 2022 -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP $1
}

show_params

for branch in $BRANCHES
do
    export BRANCH_NAME=$(echo $branch|jq -r '.branchName')
    export RG_LOCATION=$(echo $branch|jq -r '.location')
    export RG_NAME=$PREFIX-reddog-$BRANCH_NAME-$RG_LOCATION
    export CLUSTER_IP_ADDRESS=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterIP.value)
    export CLUSTER_FQDN=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .clusterFQDN.value)
    
    # Get the host name for the control host
    JUMP_VM_NAME=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .jumpVMName.value)
    echo "Jump Host Name: $JUMP_VM_NAME" 
    JUMP_IP=$(cat ./outputs/$RG_NAME-bicep-outputs.json | jq -r .publicIP.value)
    echo "Jump IP Address: $JUMP_IP" 

    run_on_jumpbox "sudo apt install -y rabbitmq-server"
    run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD list exchanges"
    run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare queue name="corp-transfer-orders" durable=true auto_delete=true"
    run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare queue name="corp-transfer-ordercompleted" durable=true auto_delete=true"
    run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD list queues"
    run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare binding source="orders" destination_type="queue" destination="corp-transfer-orders""
    run_on_jumpbox "rabbitmqadmin -H 10.128.1.4 -u contosoadmin -p $RABBIT_MQ_PASSWD declare binding source="ordercompleted" destination_type="queue" destination="corp-transfer-ordercompleted""

    # create the corp-transfer-fx on k8s
    export RABBIT_CONNECT_STRING="amqp://contosoadmin:${RABBIT_MQ_PASSWD}@rabbitmq.rabbitmq.svc.cluster.local:5672"
    echo "RabbitMQ: ${RABBIT_CONNECT_STRING}"

    SB_NAME=$(jq -r .serviceBusName.value ./outputs/brian3-reddog-hub-eastus-bicep-outputs.json)
    echo "Service Bus Name: ${SB_NAME}"
    RG_NAME='brian3-reddog-hub-eastus'

    SB_CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list \
    --resource-group $RG_NAME \
    --namespace-name  $SB_NAME \
    --name RootManageSharedAccessKey -o json | jq -r '.primaryConnectionString')

    echo "Service Bus: ${SB_CONNECTION_STRING}"
     
    #run_on_jumpbox "kubectl create secret generic -n reddog-retail corp-transfer-service --from-literal=FUNCTIONS_WORKER_RUNTIME=node --from-literal=rabbitMQConnectionAppSetting=${RABBIT_CONNECT_STRING} --from-literal=MyServiceBusConnection=${SB_CONNECT_STRING}"
    #run_on_jumpbox "kubectl apply -f $BASEDIR/manifests/corp-transfer-fx.yaml -n reddog-retail

done