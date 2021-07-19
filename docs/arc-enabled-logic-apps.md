# Logic Apps in an App Service Kubernetes Environment

** Note: this assumes that you already have an Azure Arc enabled Kubernetes cluster

## Creating the App Service Environment (in Kubernetes)

* [Setting up an Azure Arc enabled Kubernetes cluster to run App Service](https://docs.microsoft.com/en-us/azure/app-service/manage-create-arc-environment)

## Creating a custom location for the Logic Apps deployment

* After creating the App Service extension, you can [create a custom location](https://docs.microsoft.com/en-us/azure/app-service/manage-create-arc-environment#create-a-custom-location)

## Prereqs/Notes before installing Logic Apps

** Note: This is only for Logic Apps (Standard), not consumption

* If you created already created your App Service bundle on your Kubernetes cluster, make `keda.enabled=true` was included in the configuration settings.
  * [Changing the scaling behavior for Logic App workflows](https://docs.microsoft.com/en-us/azure/logic-apps/azure-arc-enabled-logic-apps-create-deploy-workflows?tabs=azure-cli#change-scaling-threshold)
* If your workflows need to use any Azure-hosted connections (like [Azure Communication Services](https://docs.microsoft.com/en-us/azure/communication-services/overview)), you must create an Azure AD app registration and take note of the client ID, object ID, tenant ID, and client secret values
* If a storage account for the Logic app doesn't already exist, [you should create one](https://docs.microsoft.com/en-us/cli/azure/storage/account#az_storage_account_create)
* Ensure that you have the preview Azure Logic Apps (Standard) extension for Azure CLI installed (or the VS Code extension):

```
$ az extension add --yes --source "https://aka.ms/logicapp-latest-py2.py3-none-any.whl"
```

## Creating a Logic App in the App Service

* Follow [this guide](https://docs.microsoft.com/en-us/azure/logic-apps/azure-arc-enabled-logic-apps-create-deploy-workflows?tabs=visual-studio-code#create-and-deploy-logic-apps)
* Use the current resource group, Arc Enabled Kubernetes Cluster, and custom location
