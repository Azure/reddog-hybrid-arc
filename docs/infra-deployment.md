## Demo Deployment Instructions

We have utilized Bicep to automatically deploy the demo application. The Hub deployment is separate from the branch(es). There are bash scripts and config files that must be setup to get started. 

### Hub (Corporate)

This step will deploy the Corp environment used by the app. It includes:
* Azure Kubernetes Service
* Azure SQL Server and Database
* CosmosDB - with database and container
* Key Vault
* Service Bus
* Storage Account
* App Service Web App
* Log Analytics Workspace

Still to be added:
* Pre-create SQL DB user
* Key Vault secrets

Instructions:
* Edit the ```config.json``` file with desired settings
    * Uniqueness is needed for some of the resources. When the RG name is set, be sure it is something unique
    * The "branches" section is not used by this script
* Set the ```var.sh``` values to match your environment
* On MacOS, install `jq`, ie, `brew install jq`
* On Linux (Debian based), install `jq`, ie, `apt install jq`
* Modify the `config.json` file to reflect your environment
* Run the script

```bash
# deploy
cd ./infra/hub/bicep/scripts
./run.sh

# cleanup
./cleanup.sh
```

### Branch

This step will deploy a Branch or store environment used by the app. Multiple branches can be deployed. It includes:
* VM (Jump Box)
* VM (K8s control plane)
* VM Scale Set (K8s nodes)
* Virtual Network
* Rancher K3s
* Managed Identity

Still to be added:
* Kubernetes secrets

Instructions:
* Edit the ```config.json``` file with desired settings
    * Go to infra/branch/bicep/scripts:ensure you have config.json in that dir
    * If not copy config.json.example to a new config.json file
    * Fill out the missing details (sub ID and tenant ID)
    * Uniqueness is needed for some of the resources. When the RG name is set, be sure it is something unique
* Set the ```var.sh``` values to match your environment
* Modify the `config.json` file to reflect your environment
* Run the script

```bash
cd ./infra/k3s/bicep/scripts
./run.sh
* Once the script has finished there should be a logs file at infra/branch/bicep/scripts/logs/name-of-your-rg.log
* Last line should have the output Jump box connection info: ssh reddogadmin@52.234.158.87 -i ./ssh_keys/rk1_id_rsa
* Use that ssh command to remote into your jumpbox
* Verify that the pods in reddog-retail name space are running/ok - with the exception of the bootstrapper pod
* Verify that the UI app is working/accessible by going to the public ip or FQDN of your loadbalancer on port :8081 in a browser
    * e.g. http://rk1brooklin-k3s-worker-pub-ip.eastus.cloudapp.azure.com:8081/#/dashboardRinse 

# cleanup
./cleanup.sh
```





