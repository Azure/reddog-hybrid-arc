param name string
param adminUsername string
param adminPublicKey string
param subnetId string

var defaultAksSettings = {
  kubernetesVersion: null
  identity: 'SystemAssigned'
  networkPlugin: 'azure'
  networkPolicy: 'calico'
  serviceCidr: '172.16.0.0/22' // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
  dnsServiceIP: '172.16.0.10' // Ip Address for K8s DNS
  dockerBridgeCidr: '172.16.4.1/22' // Used for the default docker0 bridge network that is required when using Docker as the Container Runtime.  Not used by AKS or Docker and is only cluster-routable.  Cluster IP based addresses are allocated from this range.  Can be safely reused in multiple clusters.
  loadBalancerSku: 'standard'
  //sku_tier: 'Paid'				
  enableRBAC: true 
  aadProfileManaged: true
}

var defaultNodePoolSettings = {
  name: 'defaultpool'
  orchestratorVersion: null
  
  vmSize: 'Standard_D2s_v3'
  osType: 'Linux'
  osDiskSizeGB: 50
  osDiskType: 'Ephemeral'
  type: 'VirtualMachineScaleSets'
  count: 3

  vnetSubnetID: subnetId
  minCount: 2
  maxCount: 3
  maxPods: 30
  
  enableAutoScaling: true
  upgradeSettings: {
    maxSurge: '1'
  }

  tags: {}
  nodeLabels: {}
  nodeTaints: []
}

var defaultSystemNodePoolSettings = union(defaultNodePoolSettings, {
  mode: 'System' // setting this to system type for just k8s system services
  // nodeTaints: [
  //   'CriticalAddonsOnly=true:NoSchedule' // adding to ensure that only k8s system services run on these nodes
  // ]
})

resource aks 'Microsoft.ContainerService/managedClusters@2021-03-01' = {
  name: name 
  location: resourceGroup().location  
  identity: {
    type: defaultAksSettings.identity
  }
  properties: {
    kubernetesVersion: defaultAksSettings.kubernetesVersion
    dnsPrefix: name
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: adminPublicKey
          }
        ]
      }
    }
    enableRBAC: defaultAksSettings.enableRBAC
    enablePodSecurityPolicy: false // setting to false since PSPs will be deprecated in favour of Gatekeeper/OPA

    networkProfile: {
      networkPlugin: defaultAksSettings.networkPlugin 
      networkPolicy: defaultAksSettings.networkPolicy 
      serviceCidr: defaultAksSettings.serviceCidr  // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
      dnsServiceIP: defaultAksSettings.dnsServiceIP // Ip Address for K8s DNS
      dockerBridgeCidr: defaultAksSettings.dockerBridgeCidr  // Used for the default docker0 bridge network that is required when using Docker as the Container Runtime.  Not used by AKS or Docker and is only cluster-routable.  Cluster IP based addresses are allocated from this range.  Can be safely reused in multiple clusters.
      loadBalancerSku: defaultAksSettings.loadBalancerSku 
      // networkMode: 'transparent' // defaults to transparent
      // podCidr: '' // used when networkPlugin is set to kubenet
      // loadBalancerProfile: {} // Profile for when outboundType: 'loadBalancer' - can config multiple pip etc. for cluster LB
    }

    agentPoolProfiles: [
      defaultSystemNodePoolSettings
  ]
  }
}

output name string = aks.name
