targetScope = 'subscription'

metadata name = 'CICD Agents and Runnes with existing dependencies like Log Analytics Workspace and Azure Container Registry and DNS configuration for the virtual network'
metadata description = 'This test will deploy the CICD Agents and Runners module with Azure Container Instances and Container Apps and it will use existing dependencies for Log Analytics Workspace, Azure Container Registry and DNS.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-devopsrunners-${serviceShort}-rg'

#disable-next-line no-hardcoded-location // Due to quotas and capacity challenges, this region must be used in the AVM testing subscription
var enforcedLocation = 'eastus2'

@description('Optional. The personal access token for the Azure DevOps organization.')
@secure()
param personalAccessToken string = newGuid()

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'acaacie'

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '#_namePrefix_#'

// =================
// General resources
// =================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: enforcedLocation
}

// =================
// Dependencies
// =================
module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, enforcedLocation)}-nestedDependencies'
  params: {
    namePrefix: namePrefix
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../../main.bicep' = {
  name: '${uniqueString(deployment().name, enforcedLocation)}-test-${serviceShort}'
  scope: resourceGroup
  params: {
    namingPrefix: namePrefix
    location: enforcedLocation
    computeTypes: [
      'azure-container-instance'
      'azure-container-app'
    ]
    selfHostedConfig: {
      agentsPoolName: 'agents-pool'
      devOpsOrganization: 'azureDevOpsOrganization'
      personalAccessToken: personalAccessToken
      selfHostedType: 'azuredevops'
    }
    networkingConfiguration: {
      addressSpace: '10.0.0.0/16'
      networkType: 'createNew'
      virtualNetworkName: 'vnet-aca'
      deploymentScriptPrivateDnsZoneResourceId: nestedDependencies.outputs.privateDnsFileStorageResourceId
      containerRegistryPrivateDnsZoneResourceId: nestedDependencies.outputs.acrPrivateDNSZoneResourceId
      addPrivateDnsZoneVirtualNetworkLink: true
    }
    privateNetworking: true
    logAnalyticsWorkspaceResourceId: nestedDependencies.outputs.logAnalyticsWorkspaceResourceId
  }
}
