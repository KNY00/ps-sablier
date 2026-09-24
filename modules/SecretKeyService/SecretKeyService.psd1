@{
    RootModule           = 'SecretKeyService.psm1'
    ModuleVersion        = '1.0.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID                 = 'e9c5208f-7c1b-4f93-bc47-3f41249bcf82'
    Author               = 'kny00'
    CompanyName          = 'ps-sablier'
    Copyright            = '(c) 2026. All rights reserved.'
    Description          = 'Service for managing API keys securely in the local secret store vault.'
    PowerShellVersion    = '5.1'
    FunctionsToExport    = @(
        'Initialize-SecretVaultService',
        'Set-ApiKeySecret',
        'Get-ApiKeySecret',
        'Remove-ApiKeySecret'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
}