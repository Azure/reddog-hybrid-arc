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
* Edit the ```infra.json``` file with desired settings
    * Uniqueness is needed for some of the resources. When the RG name is set, be sure it is something unique
    * The "branches" section is not used by this script
* Set the ```var.sh``` values to match your environment
* Run the script

```bash
# deploy
cd ./infra/hub/bicep
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
* Edit the ```infra.json``` file with desired settings
    * Uniqueness is needed for some of the resources. When the RG name is set, be sure it is something unique
* Set the ```var.sh``` values to match your environment
* Run the script

```bash
cd ./infra/k3s/bicep
./run.sh

# cleanup
./cleanup.sh
```





