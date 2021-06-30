param prefix string
param accessPolicies array = []

resource keyvault 'Microsoft.KeyVault/vaults@2020-04-01-preview' = {
  name: '${prefix}-keyvault'
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: accessPolicies
  }
}

output name string = keyvault.name
