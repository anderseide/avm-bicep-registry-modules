@description('Required. The name of the private DNS zone.')
param privateDnsZoneName string

@description('Required. The resource ID of the virtual network to link to the private DNS zone.')
param virtualNetworkResourceId string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZoneName
}
resource privateDnsVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: uniqueString(virtualNetworkResourceId)
  parent: privateDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkResourceId
    }
  }
}

@description('The resource ID of the created private DNS zone virtual network link.')
output privateDnsVirtualNetworkLinkResourceId string = privateDnsVirtualNetworkLink.id

@description('The name of the created private DNS zone virtual network link.')
output privateDnsVirtualNetworkLinkName string = privateDnsVirtualNetworkLink.name
