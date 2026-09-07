@{
    RootModule = 'Notification.psm1'

    # Version number of this module
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop')

    # ID used to uniquely identify this module
    GUID = '9d3fa62e-503d-4c31-b845-73ef90d98412'

    # Author of this module
    Author = 'kny00'

    # Company or vendor of this module
    CompanyName = 'ps-sablier'

    # Copyright statement for this module
    Copyright = '(c) 2026. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Toast notification and sound alert module compatible with PowerShell 5.1 and 7+.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    FunctionsToExport = @('Send-Notification')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{}
    }
}