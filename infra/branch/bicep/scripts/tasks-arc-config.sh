# Arc join the cluster
echo "Arc joining the branch cluster..."
ssh -o "StrictHostKeyChecking no" -i $SSH_KEY_PATH/$SSH_KEY_NAME $ADMIN_USER_NAME@$JUMP_IP "az connectedk8s connect -g $RG_NAME -n $PREFIX$BRANCH_NAME-branch --distribution k3s --infrastructure generic --custom-locations-oid $MI_OBJ_ID"

