#
# Module manifest for module 'SessionController'
# Generated for ps-sablier
#

@{

RootModule = 'SessionController.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = '9e419b6a-7d2e-4b68-b78f-624df5c5e8c1'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Database controller module managing SQLite3 time_sessions and task_time_sessions tables.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('SqliteUtils', 'UiNotificationUtils')

FunctionsToExport = @(
    'New-TimeSessionItem',
    'Get-TimeSessionItem',
    'Set-TimeSessionItem',
    'Add-TaskSessionLink',
    'Remove-TimeSessionItem',
    'Get-TaskSessionLinkBySessionId',
    'Remove-TaskSessionLinkBySessionId'
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
        Tags = @('SQLite', 'Session', 'Database', 'Controller', 'CLI')
        ProjectURI = ''
    }
}

}