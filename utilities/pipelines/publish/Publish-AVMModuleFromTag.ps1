<#
.SYNOPSIS
Publish module to Bicep Registry.

.DESCRIPTION
Publish module to Bicep Registry.
Checks out the tag that are requested to be published, and publishes the module to the Bicep Registry..

.PARAMETER GitTagName
Mandatory. The path to the deployment file

.PARAMETER BicepModuleRegistryServer
Mandatory. The public registry server.

.PARAMETER BicepModuleRegistryRootPath
Optional. The root path to the module in the registry. Default is 'public/avm'.

.EXAMPLE
Publish-AVMModuleFromTag -GitTagName 'avm/res/storage/storage-account/0.17.3' -BicepModuleRegistryServer 'myServer' -BicepModuleRegistryRootPath 'public/avm'
#>
function Publish-AVMModuleFromTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $GitTagName,

        [Parameter(Mandatory = $true)]
        [string] $BicepModuleRegistryServer,

        [Parameter(Mandatory = $false)]
        [string] $BicepModuleRegistryRootPath = 'public/bicep'

    )

    begin {
        # Logic to verify that the script is not running inside of a git repository that are connected to the AVM repository
        try {
            $null = git rev-parse --is-inside-work-tree
        } catch {
            Write-Error 'The script is running inside of a git repository. Please run the script outside of a git repository.'
            return
        }
    }

    process {
        # Verify that the tag exists
        $tagExists = git tag -l $GitTagName
        if (-not $tagExists) {
            Write-Error "The tag '$GitTagName' does not exist."
            return
        }

        $null, $moduleName, $moduleVersion = ($GitTagName -split '(.+)[\/](\d+.\d+.\d+)')

        $moduleMainFilePath = Join-Path $moduleName 'main.bicep'
        $target = 'br:{0}/{1}/{2}:{3}' -f $BicepModuleRegistryServer, $BicepModuleRegistryRootPath, $moduleName, $moduleVersion[0]

        Write-Verbose "Relative Module Path: $moduleMainFilePath"
        Write-Verbose "Module Name: $moduleName"
        Write-Verbose "Module version: $moduleVersion"
        Write-Verbose "Bicep Module Registry Server: $BicepModuleRegistryServer"
        Write-Verbose "publishing to $target"

        # Checkout tag
        $originalBranch = git rev-parse --abbrev-ref HEAD

        git checkout $GitTagName

        # update bicepconfig.json to override br/public

        $bicepConfigPath = 'bicepconfig.json'

        $bicepConfigRaw = Get-Content $bicepConfigPath
        $bicepConfig = $bicepConfigRaw | Where-Object { -not $_.StartsWith('//') }

        $bicepConfig = $bicepConfig | ConvertFrom-Json -AsHashtable


        Write-Host 'Testing if public exists in bicepConfig'
        if ($bicepConfig.ContainsKey('moduleAliases') -eq $false) {
            Write-Host 'Adding moduleAliases to bicepConfig'
            $bicepConfig.Add('moduleAliases', @{})
        }

        if ($bicepConfig.moduleAliases.ContainsKey('br') -eq $false) {
            Write-Host 'Adding br to bicepConfig'
            $bicepConfig.moduleAliases.Add('br', @{})
        }

        if ($bicepConfig.moduleAliases.br.ContainsKey('public')) {
            Write-Host 'Updating public in bicepConfig'
            $bicepConfig.moduleAliases.br.public.registry = $BicepModuleRegistryServer
            $bicepConfig.moduleAliases.br.public.modulePath = $BicepModuleRegistryRootPath
        } else {
            Write-Host 'Adding public to bicepConfig'
            $bicepConfig.moduleAliases.br.Add('public', @{
                    registry   = $BicepModuleRegistryServer
                    modulePath = $BicepModuleRegistryRootPath
                })
        }

        $bicepConfig | ConvertTo-Json -Depth 10 | Set-Content $bicepConfigPath

        Write-Host "Publishing $moduleMainFilePath to $target"
        Publish-AzBicepModule -FilePath $moduleMainFilePath -Target $target

        git checkout $originalBranch

    }

    end {

    }
}
