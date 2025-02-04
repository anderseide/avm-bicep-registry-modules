<#
.SYNOPSIS
This function helps with testing a module locally

.DESCRIPTION
This function helps with testing a module locally. Use this function To perform Pester testing for a module and then attempting to deploy it. It also allows you to use your own
subscription Id, principal Id, tenant ID and other parameters that need to be tokenized.

.PARAMETER TemplateFilePath
Mandatory. Path to the Bicep/ARM module that is being tested

.PARAMETER ModuleTestFilePath
Optional. Path to the template file/folder that is to be tested with the template file. Defaults to the module's default '.test' folder. Will be used if the DeploymentTest/ValidationTest switches are set.

.PARAMETER PesterTest
Optional. A switch parameter that triggers a Pester test for the module

.PARAMETER ValidateOrDeployParameters
Optional. An object consisting of the components that are required when using the Validate test or DeploymentTest switch parameter.  Mandatory if the DeploymentTest/ValidationTest switches are set.

.PARAMETER DeploymentTest
Optional. A switch parameter that triggers the deployment of the module

.PARAMETER ValidationTest
Optional. A switch parameter that triggers the validation of the module only without deployment

.PARAMETER SkipParameterFileTokens
Optional. A switch parameter that enables you to skip the search for local custom parameter file tokens.

.PARAMETER AdditionalParameters
Optional. Additional parameters you can provide with the deployment. E.g. @{ resourceGroupName = 'myResourceGroup' }

.PARAMETER AdditionalTokens
Optional. A hashtable parameter that contains custom tokens to be replaced in the paramter files for deployment

.EXAMPLE

$TestModuleLocallyInput = @{
    TemplateFilePath           = 'C:\network\route-table\main.bicep'
    ModuleTestFilePath         = 'C:\network\route-table\.test\common\main.test.bicep'
    PesterTest                 = $false
    DeploymentTest             = $false
    ValidationTest             = $true
    ValidateOrDeployParameters = @{
        Location          = 'westeurope'
        ResourceGroupName = 'validation-rg'
        SubscriptionId    = '00000000-0000-0000-0000-000000000000'
        ManagementGroupId = '00000000-0000-0000-0000-000000000000'
        RemoveDeployment  = $false
    }
    AdditionalTokens           = @{
        tenantId      = '00000000-0000-0000-0000-000000000000'
        namePrefix    = 'avm'
        moduleVersion = '1.0.0'
    }
}
Test-ModuleLocally @TestModuleLocallyInput -Verbose

Run a Test-Az*Deployment using a test file with the provided tokens

.EXAMPLE

$TestModuleLocallyInput = @{
    TemplateFilePath           = 'C:\network\route-table\main.bicep'
    PesterTest                 = $true
}
Test-ModuleLocally @TestModuleLocallyInput -Verbose

Run all Pester tests for the given template file

.EXAMPLE

$TestModuleLocallyInput = @{
    TemplateFilePath           = 'C:\network\route-table\main.bicep'
    PesterTest                 = $true
    ValidateOrDeployParameters = @{
        SubscriptionId    = '00000000-0000-0000-0000-000000000000'
        ManagementGroupId = '00000000-0000-0000-0000-000000000000'
    }
    AdditionalTokens           = @{
        tenantId      = '00000000-0000-0000-0000-000000000000'
        namePrefix    = 'avm'
        moduleVersion = '1.0.0'
    }
}
Test-ModuleLocally @TestModuleLocallyInput -Verbose

Run all Pester tests for the given template file including tests for the use of tokens

.EXAMPLE
$TestModuleLocallyInput = @{
    TemplateFilePath           = 'C:\network\route-table\main.bicep'
    ModuleTestFilePath         = 'C:\network\route-table\.test\common\main.test.bicep'
    PesterTest                 = $false
    DeploymentTest             = $false
    WhatIfTest                 = $true
    ValidationTest             = $false
    ValidateOrDeployParameters = @{
        Location          = 'westeurope'
        ResourceGroupName = 'validation-rg'
        SubscriptionId    = '00000000-0000-0000-0000-000000000000'
        ManagementGroupId = '00000000-0000-0000-0000-000000000000'
        RemoveDeployment  = $false
    }
    AdditionalTokens           = @{
        tenantId = '00000000-0000-0000-0000-000000000000'
    }
}
Test-ModuleLocally @TestModuleLocallyInput -Verbose
Get What-If deployment result using a test file with the provided tokens

.NOTES
- Make sure you provide the right information in the 'ValidateOrDeployParameters' parameter for this function to work.
- Ensure you have the ability to perform the deployment operations using your account (if planning to test deploy or performing what-if validation.)
#>
function Test-ModuleLocally {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $false)]
        [string] $ModuleTestFilePath = (Join-Path (Split-Path $TemplateFilePath -Parent) 'tests'),

        [Parameter(Mandatory = $false)]
        [string] $PesterTestFilePath = 'utilities/pipelines/staticValidation/compliance/module.tests.ps1',

        [Parameter(Mandatory = $false)]
        [Psobject] $ValidateOrDeployParameters = @{},

        [Parameter(Mandatory = $false)]
        [hashtable] $AdditionalParameters = @{},

        [Parameter(Mandatory = $false)]
        [hashtable] $AdditionalTokens = @{},

        [Parameter(Mandatory = $false)]
        [switch] $PesterTest,

        [Parameter(Mandatory = $false)]
        [switch] $PesterTestRecurse,

        [Parameter(Mandatory = $false)]
        [switch] $PSRuleTest,

        [Parameter(Mandatory = $false)]
        [string] $PSRuleBaseline = 'Azure.Default',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Pass', 'Fail', 'Error', 'None', 'Processed', 'All')]
        [string[]] $PSRuleOutcome = @('Pass', 'Fail', 'Error'),

        [Parameter(Mandatory = $false)]
        [string] $PSRuleOutputFormat = 'Markdown',

        [Parameter(Mandatory = $false)]
        [switch] $DeploymentTest,

        [Parameter(Mandatory = $false)]
        [switch] $ValidationTest,

        [Parameter(Mandatory = $false)]
        [switch] $WhatIfTest
    )

    begin {
        $repoRootPath = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
        $ModuleName = Split-Path (Split-Path $TemplateFilePath -Parent) -Leaf
        $utilitiesFolderPath = Split-Path $PSScriptRoot -Parent
        $moduleRoot = Split-Path $TemplateFilePath
        Write-Verbose "Running local tests for [$ModuleName]"
        # Load Tokens Converter Scripts
        . (Join-Path $utilitiesFolderPath 'pipelines' 'sharedScripts' 'tokenReplacement' 'Convert-TokensInFileList.ps1')
        . (Join-Path $utilitiesFolderPath 'pipelines' 'sharedScripts' 'Get-LocallyReferencedFileList.ps1')
        # Load Modules Validation / Deployment Scripts
        . (Join-Path $utilitiesFolderPath 'pipelines' 'e2eValidation' 'resourceDeployment' 'New-TemplateDeployment.ps1')
        . (Join-Path $utilitiesFolderPath 'pipelines' 'e2eValidation' 'resourceDeployment' 'Test-TemplateDeployment.ps1')
        . (Join-Path $PSScriptRoot 'helper' 'Get-TemplateDeploymentWhatIf.ps1')
    }
    process {

        ################
        # PESTER Tests #
        ################
        if ($PesterTest -or $PesterTestRecurse) {
            Write-Verbose "Pester Testing Module: $ModuleName"

            try {
                $testFiles = @(
                    (Join-Path $repoRootPath $PesterTestFilePath), # AVM Compliance Tests
                    (Join-Path $moduleRoot 'tests' 'unit')         # Module Unit Tests
                )

                $moduleFolderPaths = @(Split-Path $TemplateFilePath -Parent)
                if ($PesterTestRecurse) {
                    $moduleFolderPaths += (Get-ChildItem -Path $moduleFolderPaths -Recurse -Directory -Force).FullName | Where-Object {
                        (Get-ChildItem $_ -File -Depth 0 -Include @('main.json', 'main.bicep') -Force).Count -gt 0
                    }
                }

                Invoke-Pester -Configuration @{
                    Run    = @{
                        Container = New-PesterContainer -Path $testFiles -Data @{
                            repoRootPath      = $repoRootPath
                            moduleFolderPaths = $moduleFolderPaths
                        }
                    }
                    Output = @{
                        Verbosity = 'Detailed'
                    }
                }
            } catch {
                $PSItem.Exception.Message
            }
        }

        ################
        # PSRule Tests #
        ################

        if ($PSRuleTest) {
            # $moduleFolderPath = Split-Path $TemplateFilePath -Parent
            $psRuleOption = Join-Path $utilitiesFolderPath 'pipelines' 'staticValidation' 'psrule' 'ps-rule.yaml'
            $psRulePath = Join-Path $utilitiesFolderPath 'pipelines' 'staticValidation' 'psrule' '.ps-rule'

            Write-Host "Running PSRule tests for module: $TemplateFilePath"
            Write-Host "Using baseline: $PSRuleBaseline"
            Write-Host "Using option file: $psRuleOption"
            Write-Host "Using rule path: $psRulePath/"

            # $templateFilePath = Join-Path $env:GITHUB_WORKSPACE '${{ inputs.templateFilePath }}'

            # Get target files
            $targetFileList = @(
                $TemplateFilePath
            )

            # Add all module template files as they may contain tokens
            $targetFileList += (Get-LocallyReferencedFileList -FilePath $TemplateFilePath)
            $targetFileList = $targetFileList | Sort-Object -Unique

            # Construct Token Function Input
            $ConvertTokensInputs = @{
                FilePathList = $targetFileList
                Tokens       = @{}
            }

            # Add enforced tokens
            $ConvertTokensInputs.Tokens += @{
                subscriptionId    = 'subId'
                managementGroupId = 'mgmtId'
                tenantId          = 'tenId'
            }

            # Add local (source control) tokens
            $tokenMap = @{}
            foreach ($token in (Get-ChildItem env: | Where-Object -Property Name -Like 'localToken_*')) {
                $tokenMap += @{ $token.Name.Replace('localToken_', '', 'OrdinalIgnoreCase') = $token.value }
            }
            Write-Verbose ('Using local tokens [{0}]' -f ($tokenMap.Keys -join ', ')) -Verbose
            $ConvertTokensInputs.Tokens += $tokenMap

            # Swap 'namePrefix' token if empty and provided as a variable
            if ([String]::IsNullOrEmpty($ConvertTokensInputs.Tokens['namePrefix'])) {
                Write-Verbose 'Using static [namePrefix] token' -Verbose
                $ConvertTokensInputs.Tokens['namePrefix'] = 'psr'
            }

            Write-Verbose "Convert Tokens Input:`n $($ConvertTokensInputs | ConvertTo-Json -Depth 10)" -Verbose

            # Invoke Token Replacement Functionality [For Module]
            $null = Convert-TokensInFileList @ConvertTokensInputs

            # -InputPath 'avm/res/network/application-gateway-web-application-firewall-policy/tests/e2e/defaults/main.test.bicep'
            # -Modules 'PSRule.Rules.Azure'
            # -Source '/utilities/pipelines/staticValidation/psrule/.ps-rule/'
            # -Baseline 'Azure.Pillar.Reliability'
            # -Conventions ''
            # -Option '/home/runner/work/avm-bicep-registry-modules/avm-bicep-registry-modules//utilities/pipelines/staticValidation/psrule/ps-rule.yaml'

            $PSRuleConfig = @{
                InputPath    = $TemplateFilePath
                Module       = 'PSRule.Rules.Azure'
                Baseline     = $PSRuleBaseline
                Option       = $psRuleOption
                Path         = $psRulePath + [System.IO.Path]::DirectorySeparatorChar
                OutputFormat = $PSRuleOutputFormat
                Outcome      = $PSRuleOutcome
            }

            Invoke-PSRule @PSRuleConfig
        }

        #################################
        # Validation & Deployment tests #
        #################################

        if (($ValidationTest -or $DeploymentTest -or $WhatIfTest) -and $ValidateOrDeployParameters) {

            # Find Test Parameter Files
            # -------------------------
            if ((Get-Item -Path $ModuleTestFilePath) -is [System.IO.DirectoryInfo]) {
                $moduleTestFiles = (Get-ChildItem -Path $ModuleTestFilePath -File).FullName
            } else {
                $moduleTestFiles = @($ModuleTestFilePath)
            }

            # Construct Token Configuration Input
            $tokenConfiguration = @{
                FilePathList = @($moduleTestFiles)
                Tokens       = @{}
            }

            # Add any additional file that may contain tokens
            foreach ($testFilePath in $moduleTestFiles) {
                $tokenConfiguration.FilePathList += (Get-LocallyReferencedFileList -FilePath $testFilePath)
            }
            $tokenConfiguration.FilePathList = $tokenConfiguration.FilePathList | Sort-Object -Culture 'en-US' -Unique

            # Add other template files as they may contain the 'moduleVersion'
            $tokenConfiguration.FilePathList += (Get-ChildItem -Path $moduleRoot -Recurse -File).FullName | Where-Object { $_ -match '.+(main.json|main.bicep)$' }

            # Default tokens
            $tokenConfiguration.Tokens += @{
                subscriptionId    = $ValidateOrDeployParameters.SubscriptionId
                managementGroupId = $ValidateOrDeployParameters.ManagementGroupId
            }

            # Add Other Parameter File Tokens (For Testing)
            $AdditionalTokens.Keys | ForEach-Object {
                $tokenConfiguration.Tokens[$PSItem] = $AdditionalTokens.$PSItem
            }

            # Invoke Token Replacement Functionality and Convert Tokens in Parameter Files
            $null = Convert-TokensInFileList @tokenConfiguration

            # Deployment & Validation Testing
            # -------------------------------
            $functionInput = @{
                DeploymentMetadataLocation = $ValidateOrDeployParameters.Location
                resourceGroupName          = $ValidateOrDeployParameters.ResourceGroupName
                subscriptionId             = $ValidateOrDeployParameters.SubscriptionId
                managementGroupId          = $ValidateOrDeployParameters.ManagementGroupId
                additionalParameters       = $additionalParameters
                RepoRoot                   = $repoRootPath
                Verbose                    = $true
            }

            try {
                # Validate template
                # -----------------
                if ($ValidationTest) {
                    # Loop through test files
                    foreach ($moduleTestFile in $moduleTestFiles) {
                        Write-Verbose ('Validating module [{0}] with test file [{1}]' -f $ModuleName, (Split-Path $moduleTestFile -Leaf)) -Verbose
                        Test-TemplateDeployment @functionInput -TemplateFilePath $moduleTestFile
                    }
                }

                # What-If validation for template
                # -----------------
                if ($WhatIfTest) {
                    # Loop through test files
                    foreach ($moduleTestFile in $moduleTestFiles) {
                        Write-Verbose ('Get Deployment What-If result for module [{0}] with test file [{1}]' -f $ModuleName, (Split-Path $moduleTestFile -Leaf)) -Verbose
                        Get-TemplateDeploymentWhatIf @functionInput -TemplateFilePath $moduleTestFile
                    }
                }

                # Deploy template
                # ---------------
                if ($DeploymentTest) {
                    $functionInput['retryLimit'] = 1 # Overwrite default of 3
                    # Loop through test files
                    foreach ($moduleTestFile in $moduleTestFiles) {
                        Write-Verbose ('Deploy Module [{0}] with test file [{1}]' -f $ModuleName, (Split-Path $moduleTestFile -Leaf)) -Verbose
                        if ($PSCmdlet.ShouldProcess(('Module [{0}] with test file [{1}]' -f $ModuleName, (Split-Path $moduleTestFile -Leaf)), 'Deploy')) {
                            New-TemplateDeployment @functionInput -TemplateFilePath $moduleTestFile
                        }
                    }
                }

            } catch {
                Write-Error $_
            } finally {
                # Restore test files
                # ------------------
                if (($ValidationTest -or $DeploymentTest) -and $ValidateOrDeployParameters) {
                    # Replace Values with Tokens For Repo Updates
                    Write-Verbose 'Restoring Tokens'
                    $null = Convert-TokensInFileList @tokenConfiguration -SwapValueWithName $true
                }
            }
        }
    }
    end {
    }
}
