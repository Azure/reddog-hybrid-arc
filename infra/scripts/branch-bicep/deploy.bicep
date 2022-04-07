// Basic Naming Convention
param prefix string

// For AKV and other user IAM/RBAC
param currentUserId string

// Networking
param vnetPrefix string = '10.128.0.0/16'
param loadBalancerSubnetInfo object = {
  name: 'LoadBalancerSubnet'
  properties: {
    addressPrefix: '10.128.0.0/24'
  }
}
param k3sControlSubnetInfo object = {
  name: 'K3sControlSubnet'
  properties: {
    addressPrefix: '10.128.1.0/24'
  }
}
param k3sWorkersSubnetInfo object = {
  name: 'K3sWorkerSubnet'
  properties: {
    addressPrefix: '10.128.2.0/24'   
  }
}
param jumpboxSubnetInfo object = {
  name: 'JumpboxSubnet'
  properties: {
    addressPrefix: '10.128.3.0/24'
  }
}

// Linux Config
param adminUsername string
param adminPublicKey string
param k3sToken string

// KeyVault Secrets
param rabbitmqconnectionstring string
param redispassword            string

// Variables
var name = '${prefix}-k3s'
var controlName = '${name}-control'
var jumpName = '${name}-jump'
var workerName = '${name}-worker'
var contributorDefId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var loadBalancerSubnet = {
  name: loadBalancerSubnetInfo.name
  properties: {
    addressPrefix: loadBalancerSubnetInfo.properties.addressPrefix
    networkSecurityGroup: {
      id: loadBalancerSubnetNsg.id
    }    
  }
}
var k3sControlSubnet = {
  name: k3sControlSubnetInfo.name
  properties: {
    addressPrefix: k3sControlSubnetInfo.properties.addressPrefix
    networkSecurityGroup: {
      id: controlSubnetNsg.id
    }     
  }
}
var k3sWorkersSubnet = {
  name: k3sWorkersSubnetInfo.name
  properties: {
    addressPrefix: k3sWorkersSubnetInfo.properties.addressPrefix
    networkSecurityGroup: {
      id: workerSubnetNsg.id
    }       
  }
}
var jumpboxSubnet = {
  name: jumpboxSubnetInfo.name
  properties: {
    addressPrefix: jumpboxSubnetInfo.properties.addressPrefix
    networkSecurityGroup: {
      id: jumpboxSubnetNsg.id
    }       
  }
}

// ************** Resources **************
resource userAssignedMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${prefix}branchManagedIdentity'
  location: resourceGroup().location
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorDefId, resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorDefId)
    principalId: userAssignedMI.properties.principalId
  }
}

// Create VNET
resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: '${prefix}-k3s-${resourceGroup().location}-vnet'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      loadBalancerSubnet
      k3sControlSubnet
      k3sWorkersSubnet
      jumpboxSubnet
    ]
  }
}

resource receiptstorage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: '${prefix}receipts'
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource receiptscontainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${receiptstorage.name}/default/receipts'
  properties: {
    publicAccess: 'None'
  }
}

module control 'modules/k3s/control.bicep' = {
  name: '${controlName}-deployment'
  params: {
    name: controlName 
    subnetId: '${vnet.id}/subnets/${k3sControlSubnetInfo.name}'
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    k3sToken: k3sToken
  } 
}

module jump 'modules/k3s/jump.bicep' = {
  name: '${jumpName}-deployment'
  params: {
    name: jumpName 
    subnetId: '${vnet.id}/subnets/${jumpboxSubnetInfo.name}'
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    managedIdentity: userAssignedMI.id
  }
}

module workers 'modules/k3s/workers.bicep' = {
  name: '${workerName}-deployment'
  params: {
    name: workerName 
    control: '${name}-control'
    prefix: prefix
    count: 3
    subnetId: '${vnet.id}/subnets/${k3sWorkersSubnetInfo.name}'
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    k3sToken: k3sToken
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: '${prefix}-kv'
  params: {
    prefix: prefix
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
      {
        objectId: currentUserId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
      }
    ]
  }
}


resource rabbitmqsecret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  dependsOn: [
    keyvault
  ]
  name: '${keyvault.name}/rabbitmq-connectionstring'
  properties: {
    value: rabbitmqconnectionstring
  }
}

resource redissecret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  dependsOn: [
    keyvault
  ]
  name: '${keyvault.name}/redis-password'
  properties: {
    value: redispassword
  }
}

resource blobstoragenamesecret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  dependsOn: [
    keyvault
  ]
  name: '${keyvault.name}/storage-account-name'
  properties: {
    value: receiptstorage.name
  }
}

resource blobstoragecontainernamesecret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  dependsOn: [
    keyvault
  ]
  name: '${keyvault.name}/storage-container-name'
  properties: {
    value: receiptscontainer.name
  }
}

resource blobstoragekeysecret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  dependsOn: [
    keyvault
  ]
  name: '${keyvault.name}/blob-storage-key'
  properties: {
    value: receiptstorage.listKeys().keys[0].value
  }
}

resource loadBalancerSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${name}-loadbalancer-subnet-nsg'
  location: resourceGroup().location
}

resource controlSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${name}-control-subnet-nsg'
  location: resourceGroup().location
}

resource workerSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${name}-worker-subnet-nsg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'allow-inet-inbound-ui-8081'
        properties: {
          access: 'Allow'
          description: 'Allow Internet Inbound traffic on :8081'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '8081'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }    
    ]
  }
}

resource jumpboxSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${name}-jump-subnet-nsg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'allow-inet-inbound-ssh-2022'
        properties: {
          access: 'Allow'
          description: 'Allow Internet Inbound traffic on: 2022'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '2022'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow-inet-inbound-kubectl-8001'
        properties: {
          access: 'Allow'
          description: 'Allow Internet Inbound traffic on: 8001'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '8001'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }          
    ]
  }
}

// Outputs
output publicIP string = jump.outputs.jumpPublicIP
output controlName string = controlName
output jumpVMName string = jump.outputs.jumpVMName
output userAssignedMIAppID string = userAssignedMI.properties.clientId
output keyvaultName string = keyvault.outputs.name
output storageAccountName string = receiptstorage.name
output clusterIP string = workers.outputs.publicIP
output clusterFQDN string = workers.outputs.fqdn
