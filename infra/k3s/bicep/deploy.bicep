// Basic Naming Convention
param prefix string

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

// Jump Server Managed Identity
param jumpManagedIdentity string

var name = '${prefix}-k3s'
var controlName = '${name}-control'
var jumpName = '${name}-jump'
var workerName = '${name}-worker'

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
      loadBalancerSubnetInfo
      k3sControlSubnetInfo
      k3sWorkersSubnetInfo
      jumpboxSubnetInfo
    ]
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
    managedIdentity: jumpManagedIdentity
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

// Outputs
output publicIP string = jump.outputs.jumpPublicIP
output controlName string = controlName

