@description('Optional. A token to inject into the name of each resource.')
param namePrefix string

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.5.0' = {
  name: 'dep-logAnalyticsWorkspace'
  params: {
    name: 'law-${namePrefix}-${uniqueString(resourceGroup().id)}-law'
  }
}

module privateDnsFileStorage 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'dep-filesdns${namePrefix}${uniqueString(resourceGroup().id)}'
  params: {
    name: 'privatelink.file.${environment().suffixes.storage}'
  }
}

module acrPrivateDNSZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'dep-acrdnszone${namePrefix}${uniqueString(resourceGroup().id)}'
  params: {
    name: 'privatelink.azurecr.io'
  }
}

@description('The resource ID of the created log analytics workspace.')
output logAnalyticsWorkspaceResourceId string = logAnalyticsWorkspace.outputs.resourceId

@description('The resource ID of the created private DNS zone for the file storage account.')
output privateDnsFileStorageResourceId string = privateDnsFileStorage.outputs.resourceId

@description('The resource ID of the created private DNS zone for the Azure Container Registry.')
output acrPrivateDNSZoneResourceId string = acrPrivateDNSZone.outputs.resourceId
