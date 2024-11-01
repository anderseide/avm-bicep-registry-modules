<#
.SYNOPSIS
Convert the given template file path into a valid Container Registry repository name

.DESCRIPTION
Convert the given template file path into a valid Container Registry repository name

.PARAMETER TemplateFilePath
Mandatory. The template file path to convert

.EXAMPLE
Get-BRMRepositoryName -TemplateFilePath 'C:\avm\res\key-vault\vault\main.bicep'

Convert 'C:\avm\res\key-vault\vault\main.bicep' to e.g. 'avm/res/key-vault/vault'
#>
function Get-BRMRepositoryName {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath
    )

    $moduleIdentifier = (Split-Path $TemplateFilePath -Parent) -split '[\/|\\](\w+)[\/|\\](res|ptn|utl)[\/|\\]'
    return ('{0}/{1}/{2}' -f $moduleIdentifier[1], $moduleIdentifier[2], $moduleIdentifier[3]) -replace '\\', '/'
}
