#
# Module manifest for module 'UiNotificationUtils'
# Generated for ps-sablier
#

@{

RootModule = 'UiNotificationUtils.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = 'e7b1a23c-4d5e-4f67-89ab-123456789abc'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'User-friendly CLI feedback and styled notification utilities for terminal applications.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

FunctionsToExport = @(
    'Show-ErrorMessage',
    'Show-WarningMessage',
    'Show-SuccessMessage',
    'Show-InfoMessage'
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
        Tags = @('Console', 'UI', 'Notification', 'CLI', 'Formatting')
        ProjectURI = ''
    }
}

}