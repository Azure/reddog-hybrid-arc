param prefix string

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${prefix}reddoghubsa'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {

  }
}

output name string = storageaccount.name
