param name string = 'reddog-loganalytics'
param location string = resourceGroup().location
param sku string = 'Standard'
param retentionInDays int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
  }
}
