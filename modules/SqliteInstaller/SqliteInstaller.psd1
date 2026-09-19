#
# Module manifest for module 'SqliteInstaller'
# Generated for ps-sablier
#

@{

RootModule = 'SqliteInstaller.psm1'

# Version number of this module
ModuleVersion = '2.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = 'e2b9c714-4a2e-4f90-8d5b-3a8c7e1f9a02'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Pre-flight validator for embedded .NET SQLite assemblies.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

FunctionsToExport = @(
    'Test-SqliteDotNetInstalled'
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
        Tags = @('SQLite', 'Validation')
        ProjectURI = ''
    }
}

}