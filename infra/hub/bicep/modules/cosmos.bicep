param prefix string = 'reddog'
param locations array = [
  {
    locationName: resourceGroup().location
  }
]
param databaseName string = toLower('reddog')

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: '${prefix}-cosmos-${resourceGroup().location}'
  location: resourceGroup().location
  properties: {
    locations: locations
    databaseAccountOfferType: 'Standard'
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2020-04-01' = {
  name: '${cosmos.name}/${databaseName}'
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: 1000
    }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  parent: cosmosDb
  name: 'loyalty'
  properties: {
    resource: {
      id: 'loyalty'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
  }
}  
