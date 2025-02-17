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
        [string] $BicepModuleRegistryRootPath = 'public/avm'

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

        Write-Host "Relative Module Path: $moduleMainFilePath"
        Write-Host "Module Name: $moduleName"
        Write-Host "Module version: $moduleVersion[0]"
        Write-Host "Bicep Module Registry Server: $BicepModuleRegistryServer"

        $target = 'br:{0}/{1}/{2}:{3}' -f $BicepModuleRegistryServer, $BicepModuleRegistryRootPath, $moduleName, $moduleVersion[0]
        Write-Host "publishing to $target"

        # Checkout tag
        $originalBranch = git rev-parse --abbrev-ref HEAD

        git checkout $GitTagName

        Publish-AzBicepModule -FilePath $moduleMainFilePath -Target $target

        git checkout $originalBranch


    }

    end {

    }
}
