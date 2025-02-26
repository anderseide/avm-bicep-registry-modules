@description('Optional. A token to inject into the name of each resource.')
param namePrefix string

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.5.0' = {
  name: 'logAnalyticsWorkspace'
  params: {
    name: 'law-${namePrefix}-${uniqueString(resourceGroup().id)}-law'
  }
}
