param name string = 'reddogcorp'
param location string = resourceGroup().location
param sku string = 'S1'
param tier string = 'Standard'
param siteContainerImage string = 'chzbrgr71/reddog-ui:e11c58e'
param makeLineBaseUrl string = 'http://makeline.corp.reddog.io'
param accountingBaseUrl string = 'http://accounting.corp.reddog.io'

var uniqueId  = uniqueString(resourceGroup().id) 
var uniquePrefix = '${name}${uniqueId}'
var appServicePlanName = 'farm-${uniquePrefix}'
var webSiteName = 'ui-${uniquePrefix}'

resource site 'microsoft.web/sites@2020-06-01' = {
  name: webSiteName
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'VUE_APP_MAKELINE_BASE_URL'
          value: makeLineBaseUrl
        }
        {
          name: 'VUE_APP_ACCOUNTING_BASE_URL'
          value: accountingBaseUrl
        }
      ]
      linuxFxVersion: siteContainerImage
    }
    serverFarmId: appServicePlan.id
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: sku
    tier: tier
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

output publicUrl string = site.properties.defaultHostName
