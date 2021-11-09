param prefix string

resource servicebus 'Microsoft.ServiceBus/namespaces@2021-01-01-preview' = {
  name: '${prefix}-servicebus-${resourceGroup().location}'
  location: resourceGroup().location
  sku: {
    name: 'Standard' 
  }
  properties: {}
}

resource ordercompleted 'Microsoft.ServiceBus/namespaces/topics@2018-01-01-preview' = {
  parent: servicebus
  name: 'ordercompleted'
  properties: {

  }
}

resource orders 'Microsoft.ServiceBus/namespaces/topics@2018-01-01-preview' = {
  parent: servicebus
  name: 'orders'
  properties: {

  }
}

