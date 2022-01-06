#!/usr/bin/env bash

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
