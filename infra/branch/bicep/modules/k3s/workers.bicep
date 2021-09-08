param prefix string
param count int = 2

param subnetId string
//param loadBalancerBackendAddressPools array

param vmSize string = 'Standard_D4s_v3'
param adminUsername string
param adminPublicKey string
//param customData string
param diskSizeGB int = 50

//param mastersFQDN string

param name string
param control string

param k3sToken string

var lbName = '${name}-lb'

var uiPort = 8081

var customData = base64(format('''
#cloud-config
package_upgrade: true
runcmd:
  - curl -sfL https://get.k3s.io | K3S_URL=https://{0}:6443 K3S_TOKEN={1} sh -s -
''',control,k3sToken))

resource pubip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${name}-pub-ip'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
   publicIPAllocationMethod: 'Static'
   dnsSettings: {
     domainNameLabel: '${name}-pub-ip'
   }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: lbName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: '${name}-frontend-ip'
        properties: {
          publicIPAddress: {
            id: pubip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'k3sworkers'
      }  
    ]
    loadBalancingRules: [
      {
        name: 'ui-inbound'
        properties: {
          backendAddressPools:[
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'k3sworkers')
            }
          ]
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, '${name}-frontend-ip')
          }
          frontendPort: uiPort
          backendPort: uiPort
          protocol: 'Tcp'
        }
      }  
    ]
    // outboundRules: [
      
    // ]
    // probes: [
      
    // ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${name}-nsg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'allow-inet-inbound-${uiPort}'
        properties: {
          access: 'Allow'
          description: 'Allow Internet Inbound traffice on :${uiPort}'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '${uiPort}'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

resource workers 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: '${name}-vmss'
  location: resourceGroup().location
  sku: {
    name:vmSize
    capacity: count
  }
  properties: {
    upgradePolicy: {
       mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: name
        adminUsername: adminUsername
        customData: customData
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: adminPublicKey
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '18.04-LTS'
          version: 'latest'
        }
        osDisk: {
          osType: 'Linux'
          createOption: 'FromImage'
          diskSizeGB: diskSizeGB
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${prefix}-nic'
            properties: {
              primary: true
              networkSecurityGroup: {
                id: nsg.id
              }
              ipConfigurations:[
                {
                  name: '${prefix}-nic-priv-ip'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: '${loadBalancer.id}/backendAddressPools/k3sworkers'
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }     
   }
  
}

output publicIP string = pubip.properties.ipAddress
output fqdn string = pubip.properties.dnsSettings.fqdn
