## Demo Deployment Instructions

We have utilized Bicep to automatically deploy the demo application. The Hub deployment is separate from the branch(es). There are bash scripts and config files that must be setup to get started. 

### Hub (Corporate)

This step will deploy the Corp environment used by the app. It includes:
* Azure Kubernetes Service
* Azure SQL Server
* CosmosDB
* Key Vault
* Service Bus
* Storage Account

Still to be added:
* App Service Web App
* Cosmos Database and container
* Azure SQL Database
* Log Analytics
* Key Vault secrets

Instructions:
* Edit the ```infra.json``` file with desired settings
    * Uniqueness is needed for some of the resources. When the RG name is set, be sure it is something unique
    * The "branches" section is not used by this script
* Set the ```var.sh``` values to match your environment
* Run the script

```bash
cd ./infra/hub/bicep
./run.sh
```

### Branch

This step will deploy a Branch or store environment used by the app. Multiple branches can be deployed. It includes:
* VM Scale Set
* Rancher K3s

Still to be added:
* Kubernetes secrets

Instructions:
* Edit the ```infra.json``` file with desired settings
    * Uniqueness is needed for some of the resources. When the RG name is set, be sure it is something unique
* Set the ```var.sh``` values to match your environment
* Run the script

```bash
cd ./infra/k3s/bicep
./run.sh
```





