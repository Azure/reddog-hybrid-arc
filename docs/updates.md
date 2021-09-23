## Updates

```bash

export RG_NAME=br-reddog-casper-eastus
az connectedk8s show --name $RG_NAME-branch --resource-group $RG_NAME -o json

# Lima
https://docs.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=bash

az k8s-extension create \
    --resource-group $RG_NAME \
    --name "appservice-ext" \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace "appservice-ns" \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=appservice-ns" \
    --configuration-settings "clusterName=reddog-kube-env" \
    --configuration-settings "loadBalancerIp=52.149.145.107" \
    --configuration-settings "keda.enabled=false" \
    --configuration-settings "buildService.storageClassName=local-path" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=appservice-ns/kube-environment-config" 

az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --resource-group $RG_NAME \
    --name appservice-ext -o json

az k8s-extension delete \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --resource-group $RG_NAME \
    --name appservice-ext

# APIM
https://docs.microsoft.com/en-us/azure/api-management/how-to-deploy-self-hosted-gateway-azure-arc

az k8s-extension create \
    --cluster-type connectedClusters \
    --cluster-name $RG_NAME-branch \
    --resource-group $RG_NAME \
    --name apim-arc \
    --extension-type Microsoft.ApiManagement.Gateway \
    --scope namespace \
    --target-namespace apim-arc \
    --configuration-settings gateway.endpoint='https://br-reddog-apim.management.azure-api.net/subscriptions/471d33fd-a776-405b-947c-467c291dc741/resourceGroups/br-reddog-casper-eastus/providers/Microsoft.ApiManagement/service/br-reddog-apim?api-version=2021-01-01-preview' \
    --configuration-protected-settings gateway.authKey='GatewayKey reddog&202110231850&nsr2+8l079LdVvGH3hjaHSNxhbQvrvauXtzmvrhtujVwlkJ9wMZhqMakeyBnavOSf15SPF7j0r6XkCJwRk9T+Q==' \
    --configuration-settings service.type='NodePort' \
    --release-train preview

az k8s-extension show --cluster-type connectedClusters --cluster-name $RG_NAME-branch --resource-group $RG_NAME --name apim-arc

```
