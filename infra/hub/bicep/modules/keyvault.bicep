param prefix string
param accessPolicies array = []
var uniqueId  = take(uniqueString(resourceGroup().id), 4) 
var keyvaultname = '${prefix}-kv-${uniqueId}'

resource keyvault 'Microsoft.KeyVault/vaults@2020-04-01-preview' = {
  name: keyvaultname
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: accessPolicies
    enableSoftDelete: false
  }
}

output name string = keyvault.name
