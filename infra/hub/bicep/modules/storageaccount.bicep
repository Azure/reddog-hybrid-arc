param prefix string

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${prefix}sa${resourceGroup().location}'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {

  }
}