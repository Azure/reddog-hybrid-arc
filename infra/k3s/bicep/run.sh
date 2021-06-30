# Set Variables from var.sh
source ./var.sh

# Show Params
# Set Variables
echo "Parameters"
echo "------------------------------------------------"
echo "ARM_DEPLOYMENT_NAME: $ARM_DEPLOYMENT_NAME"
echo "SUBSCRIPTION: $SUBSCRIPTION"
echo "TENANT_ID: $TENANT_ID"
echo "K3S_TOKEN: $K3S_TOKEN"
echo "ADMIN_USER_NAME: $ADMIN_USER_NAME"
echo "SSH_KEY_PATH: $SSH_KEY_PATH"
echo "------------------------------------------------"

#Generate ssh-key pair
echo "Creating ssh key directory..."
mkdir $SSH_KEY_PATH

echo "Generating ssh key..."
ssh-keygen -f $SSH_KEY_PATH/id_rsa -N ''
chmod 400 $SSH_KEY_PATH/id_rsa
export SSH_PRIV_KEY="$(cat $SSH_KEY_PATH/id_rsa)"
export SSH_PUB_KEY="$(cat $SSH_KEY_PATH/id_rsa.pub)"

# Loop through infra.json and create branches
for branch in $(cat infra.json|jq -c '.branches[]')
do
export PREFIX=$(echo $branch|jq -r '.rgName')
export RG_LOCATION=$(echo $branch|jq -r '.location')
export RG_NAME=$PREFIX-$RG_LOCATION

# Create Branch
./branch_create.sh > $RG_NAME.log 2>&1 &
pids[${i}]=$!
echo "$PREFIX Branch Creation PID: $pids"
done

# wait for all pids
for pid in ${pids[*]}; do
    echo "Waiting for PID: $pid"
    wait $pid
    echo "PID $pid complete!"
done
