<#
.SYNOPSIS
    Module manifest for the SQLiteLoader PowerShell module.

.DESCRIPTION
    Provides a Windows-exclusive (x64/ARM64) secure loader for Microsoft.Data.Sqlite
#>
@{
    # Script file (.psm1) that is executed when the module is imported
    RootModule           = 'SQLiteLoader.psm1'
    
    # Version number of the module
    ModuleVersion        = '1.1.0'
    
    # ID used to uniquely identify this module
    GUID                 = '3b2d185e-e67c-47bc-8772-2d1b7fa5701c'
    
    # Author of this module
    Author               = 'kny00'
    
    # Description of the functionality provided by this module
    Description          = 'Windows-exclusive (x64/ARM64) secure loader for Microsoft.Data.Sqlite supporting PowerShell 5.1 and 7+.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion    = '5.1'
    
    # Editions of PowerShell that this module is compatible with
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # Functions to export from this module, for best performance use explicit naming
    FunctionsToExport    = @('Initialize-SqliteDriver')
    
    # Cmdlets to export from this module
    CmdletsToExport      = @()
    
    # Variables to export from this module
    VariablesToExport    = @()
    
    # Aliases to export from this module
    AliasesToExport      = @()
}