param prefix string = 'reddog'
param location string = resourceGroup().location
param adminUsername string
param adminPassword string
param sqlDBName string = 'reddog-corp'

resource azuresql 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: '${prefix}-sqlserver'
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.2'
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${azuresql.name}/${sqlDBName}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

output name string = azuresql.name
