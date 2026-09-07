#
# Module manifest for module 'SessionUtils'
# Generated for ps-sablier
#

@{

RootModule = 'SessionUtils.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = 'c8e4f1a2-7d3b-4e89-a5c6-9f1b2c3d4e5f'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Interactive CLI workflows and prompts for time session management and task association.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('MenuUtils', 'UiNotificationUtils', 'SessionController', 'TaskController')

FunctionsToExport = @(
    'Select-SessionType',
    'Read-SessionNotes',
    'Select-SessionCompletion',
    'Complete-TaskSessionLink',
    'Invoke-TaskLinkingPrompt'
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
        Tags = @('Console', 'CLI', 'Session', 'TaskLinking')
        ProjectURI = ''
    }
}

}