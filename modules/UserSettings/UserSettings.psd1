#
# Module manifest for module 'UserSettings'
# Generated for ps-sablier
#

@{

RootModule = 'UserSettings.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = '5d4e3f2a-1b0c-4e9f-8a7d-6c5b4a3e2f10'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'User configuration management module persisting settings to local app data.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

FunctionsToExport = @(
    'Get-UserSetting',
    'Set-UserSetting',
    'Get-UserSoundPath',
    'Get-UserSkipIntro'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module
AliasesToExport = @()

# Private data to pass to the module specified in RootModule
PrivateData = @{
    PSData = @{
        Tags = @('Settings', 'Configuration', 'JSON', 'UserSettings', 'CLI')
        ProjectURI = ''
    }
}

}