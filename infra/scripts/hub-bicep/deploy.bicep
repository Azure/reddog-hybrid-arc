// Naming convention requirements
param prefix string

param location string = resourceGroup().location

// Network Settings
param vnetPrefix string = '10.0.0.0/16'
param aksSubnetInfo object = {
  name: 'AksSubnet'
  properties: {
    addressPrefix: '10.0.4.0/22'
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

// Linux Config
param adminUsername string
param adminPublicKey string

// SQL Config
param sqlAdminUsername string
param sqlAdminPassword string

// Key Vault Config
param currentUserId string
//param keyVaultSPObjectId string

var name = '${prefix}-hub'
// var jumpName = '${name}-jump'

var aksSubnet = {
  name: aksSubnetInfo.name
  properties: {
    addressPrefix: aksSubnetInfo.properties.addressPrefix
    networkSecurityGroup: {
      id: aksSubnetNsg.id
    }       
  }
}

//
// Top Level Resources
//

resource vnet 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: '${prefix}-hub-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      aksSubnet
    ]
  } 
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    prefix: name
    location: location
    accessPolicies: [
      {
        objectId: currentUserId
        tenantId: subscription().tenantId
        permissions: {
          certificates: [
            'get'
            'create'
          ]
        }
      }
      // {
      //   objectId: keyVaultSPObjectId
      //   tenantId: subscription().tenantId
      //   permissions: {
      //     secrets: [
      //       'get'
      //     ]
      //   }
      // }
    ]
  }
}

module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos'
  params: {
    prefix: name
    locations: [
      {
        locationName: location
      }
    ]
  }
}

module sqlServer 'modules/sqlazure.bicep' = {
  name: 'sqlserver'
  params: {
    prefix: name
    location: location
    adminUsername: sqlAdminUsername
    adminPassword: sqlAdminPassword
  }
}

module servicebus 'modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    location: location
    prefix: name
  }
}

module loganalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    location: location
    retentionInDays: 30
  }
}

// module webapp 'modules/webapp.bicep' = {
//   name: 'webapp'
//   params: {
//     sku: 'S1'
//   }
// }

module storageaccount 'modules/storageaccount.bicep' = {
  name: 'storageaccount'
  params: {
    location: location
    prefix: prefix
  }
}

module aks 'modules/aks.bicep' = {
  name: 'aks-deployment'
  params: {
    name: format('{0}-aks',name)
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    subnetId: '${vnet.id}/subnets/${aksSubnetInfo.name}'
    location: location
  }
  
}

resource aksSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${name}-aks-subnet-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-inet-inbound-svc-8082-8084'
        properties: {
          access: 'Allow'
          description: 'Allow Internet Inbound traffic on :8082-8084'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '8082-8084'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }    
    ]
  }
}

// Outputs
output keyvaultName string = keyvault.outputs.name
output aksName string = aks.outputs.name
output sqlServerName string = sqlServer.outputs.name
output cosmosDbName string = cosmos.outputs.name
output serviceBusName string = servicebus.outputs.name
output storageAccountName string = storageaccount.outputs.name
