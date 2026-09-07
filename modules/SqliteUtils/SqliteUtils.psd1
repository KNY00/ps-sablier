#
# Module manifest for module 'SqliteUtils'
# Generated for ps-sablier
#

@{

RootModule = 'SqliteUtils.psm1'

# Version number of this module
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = 'a3b5c7d9-2e4f-4a1b-8c6d-9e0f1a2b3c4d'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Database wrapper and fallback management supporting sqlite3 CLI and PSSQLite.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('UiNotificationUtils', 'MenuUtils', 'SqliteInstaller')

FunctionsToExport = @(
    'Get-SqliteDatabasePath',
    'Assert-SqliteDatabasePath',
    'Invoke-SqliteWrapper'
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
        Tags = @('SQLite', 'Database', 'Storage', 'CLI', 'PSSQLite')
        ProjectURI = ''
    }
}

}