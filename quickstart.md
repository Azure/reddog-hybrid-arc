## Quickstart

Create branch in the [Reddog repo](https://github.com/Azure/reddog-retail-demo)

Clone repo

In IDE go to infra/branch/bicep/scripts

In editor, update the settings in the config.json file
	- If the config.json file does not exist, copy config.json.example to a new config.json file

Update the settings in the config.json file
	- Fill out the missing details (sub ID and tenant ID)

Set the var.sh values to match your environment

Log into [Azure portal](https://portal.azure.com)

Go to Cloud Shell terminal and select Bash

Create storage if it does not yet exist

Go to your clouddrive:
cd clouddrive

clone the repo:
git clone git@github.com:Azure/reddog-retail-demo.git

To make sure you see reddog-retail-demo run:
dir

To execute deployment, go to: 
./reddog-retail-demo/infra/walk-the-dog.sh 

Follow prompts

Once the script has finished there should be a logs file at infra/branch/bicep/scripts/logs/name-of-your-rg.log

Last line should have the output Jump box connection info: ssh reddogadmin@52.234.158.87 -i ./ssh_keys/rk1_id_rsa

Use that ssh command to remote into your jumpbox

Verify that the pods in reddog-retail name space are running/ok - with the exception of the bootstrapper pod

Verify that the UI app is working/accessible by going to the public ip or FQDN of your loadbalancer on port :8081 in a browser
    e.g. http://rk1brooklin-k3s-worker-pub-ip.eastus.cloudapp.azure.com:8081/#/dashboardRinse 