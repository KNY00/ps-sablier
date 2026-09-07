@{
    RootModule        = 'SqliteInstaller.psm1'

    # Version number of this module
    ModuleVersion     = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop')

    FunctionsToExport = @(
        'Install-SqliteCli', `
        'Install-PSSqlite', `
        'Test-PSSqliteInstalled', `
        'Get-SqliteBackend'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()
}