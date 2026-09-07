#
# Module manifest for module 'TimeUtils'
# Generated for ps-sablier
#

@{

RootModule = 'TimeUtils.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop')

# ID used to uniquely identify this module
GUID = 'd1f5b4e8-8b9a-4e2a-9f5b-7b54a8e2193b'

# Author of this module
Author = 'kny00'

# Company or vendor of this module
CompanyName = 'ps-sablier'

# Copyright statement for this module
Copyright = '(c) 2026. All rights reserved.'

# Description of the functionality provided by this module
Description = 'CLI interactive date and time input utilities with arrow navigation and timestamp formatting.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

FunctionsToExport = @('Read-DateTimeInteractive')

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module
AliasesToExport = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess
PrivateData = @{
    PSData = @{
        Tags = @('Console', 'Interactive', 'DateTime', 'Timestamp')
        ProjectURI = ''
    }
}

}