param location string = resourceGroup().location
param sku string = 'S1'
param linuxFxVersion string = 'DOCKER|ghcr.io/azure/reddog-retail-demo/reddog-retail-ui:latest'
param makeLineBaseUrl string = 'http://makeline.corp.reddog.io'
param accountingBaseUrl string = 'http://accounting.corp.reddog.io'
param orderBaseUrl string = 'http://order.corp.reddog.io'
param siteTitle string = 'Red Dog Pharmacy'
param siteType string = 'Pharmacy'
param siteName string = 'Corp'
param name string = 'reddoghub'

var uniqueId  = uniqueString(resourceGroup().id) 
var uniquePrefix = '${name}${uniqueId}'
var appServicePlanName = 'farm-${uniquePrefix}'
var webSiteName = 'ui-${uniquePrefix}'

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: sku
  }
  kind: 'linux'
}
resource appService 'Microsoft.Web/sites@2020-06-01' = {
  name: webSiteName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appSettings: [
        {
          name: 'NODE_ENV'
          value: 'production'
        }        
        {
          name: 'VUE_APP_MAKELINE_BASE_URL'
          value: makeLineBaseUrl
        }
        {
          name: 'VUE_APP_ACCOUNTING_BASE_URL'
          value: accountingBaseUrl
        }
        {
          name: 'VUE_APP_ORDER_BASE_URL'
          value: orderBaseUrl
        }
        {
          name: 'VUE_APP_IS_CORP'
          value: 'true'
        }
        {
          name: 'VUE_APP_SITE_TITLE'
          value: siteTitle
        }
        {
          name: 'VUE_APP_SITE_TYPE'
          value: siteType
        }
        {
          name: 'VUE_APP_STORE_ID'
          value: siteName
        }        
      ]
    }
  }
}
