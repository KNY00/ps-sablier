#
# Module manifest for module 'MenuUtils'
# Generated for ps-sablier
#

@{

RootModule = 'MenuUtils.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = 'f4c6e12a-3b54-47a8-9d8e-71c504a3f120'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Interactive terminal menu selection and confirmation prompts with arrow navigation.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

FunctionsToExport = @(
    'Show-Menu',
    'Confirm-Action'
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
        Tags = @('Console', 'CLI', 'Menu', 'Interactive', 'Prompt')
        ProjectURI = ''
    }
}

}