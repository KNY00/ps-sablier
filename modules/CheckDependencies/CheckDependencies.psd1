#
# Module manifest for module 'CheckDependencies'
# Generated for ps-sablier

@{

RootModule = 'CheckDependencies.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = 'b7f1d4a8-6c3e-4f12-98a0-2d8e4f15a9b2'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Pre-flight dependency validation for tools, binaries (timer.exe), and SQLite backends.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('UiNotificationUtils', 'SqliteUtils', 'SqliteInstaller', 'MenuUtils')

FunctionsToExport = @(
    'Initialize-ProjectEnvironment',
    'Test-ProjectPrerequisite',
    'Test-Timer',
    'Test-SqliteAvailable', `
    'Confirm-SqliteAvailable'
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
        Tags = @('Dependencies', 'Validation', 'CLI', 'Preflight', 'Timer', 'SQLite')
        ProjectURI = ''
    }
}

}