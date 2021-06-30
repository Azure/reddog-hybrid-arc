param prefix string
param locations array = [
  {
    locationName: resourceGroup().location
  }
]

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: '${prefix}-cosmos-${resourceGroup().location}'
  location: resourceGroup().location
  properties: {
    locations: locations
    databaseAccountOfferType: 'Standard'
  }
}
