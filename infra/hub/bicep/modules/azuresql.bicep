param prefix string
param adminUsername string
param adminPassword string

resource azuresql 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: '${prefix}-sqlserver'
  location: resourceGroup().location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.2'
  }
}
