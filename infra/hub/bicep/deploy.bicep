// Naming convention requirements
param prefix string

// Network Settings
param vnetPrefix string = '10.0.0.0/16'
param aksSubnetInfo object = {
  name: 'AksSubnet'
  properties: {
    addressPrefix: '10.0.4.0/22'
    privateEndpointNetworkPolicies: 'Disabled'
  }
}
param jumpboxSubnetInfo object = {
  name: 'JumpboxSubnet'
  properties: {
    addressPrefix: '10.0.255.240/28'
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

//
// Top Level Resources
//

resource vnet 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: '${prefix}-hub-vnet'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      aksSubnetInfo
      jumpboxSubnetInfo
    ]
  } 
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    prefix: name
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
  }
}

module sqlServer 'modules/sqlazure.bicep' = {
  name: 'sqlserver'
  params: {
    prefix: name
    adminUsername: sqlAdminUsername
    adminPassword: sqlAdminPassword
  }
}

module servicebus 'modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    prefix: name
  }
}

module loganalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    retentionInDays: 30
  }
}

module webapp 'modules/webapp.bicep' = {
  name: 'webapp'
  params: {
    sku: 'S1'
  }
}

module storageaccount 'modules/storageaccount.bicep' = {
  name: 'storageaccount'
  params: {
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
  }
  
}

// module jump 'modules/jump.bicep' = {
//   name: '${jumpName}-deployment'
//   params: {
//     name: jumpName 
//     subnetId: '${vnet.id}/subnets/${jumpboxSubnetInfo.name}'
//     adminUsername: adminUsername
//     adminPublicKey: adminPublicKey
//     //managedIdentity: jumpManagedIdentity
//   }
//}

// Outputs
output keyvaultName string = keyvault.outputs.name
output aksName string = aks.outputs.name
output sqlServerName string = sqlServer.outputs.name
output cosmosDbName string = cosmos.outputs.name
output serviceBusName string = servicebus.outputs.name
output storageAccountName string = storageaccount.outputs.name
