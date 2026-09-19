<#
.SYNOPSIS
    SQLite Verification Module.

.DESCRIPTION
    Provides functions to check for required managed and native SQLite 
    dependencies for the SQLiteLoader module using .NET assemblies.
#>

function Test-SqliteDotNetInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # Resolve project root
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $runtimesDir = Join-Path $projectRoot "modules\SQLiteLoader\runtimes"

    # Architecture verification
    $arch = $env:PROCESSOR_ARCHITECTURE
    $nativeSubDir = if ($arch -eq 'ARM64') { "win-arm64\native\e_sqlite3.dll" } else { "win-x64\native\e_sqlite3.dll" }

    $managedDllCandidates = @(
        (Join-Path $runtimesDir "any\lib\net8.0\Microsoft.Data.Sqlite.dll"),
        (Join-Path $runtimesDir "any\lib\netstandard2.0\Microsoft.Data.Sqlite.dll")
    )

    $hasManaged = $false

    foreach ($cand in $managedDllCandidates) {
        if (Test-Path -LiteralPath $cand -PathType Leaf) {
            $hasManaged = $true
            break
        }
    }

    $nativePath = Join-Path $runtimesDir $nativeSubDir
    $hasNative = Test-Path -LiteralPath $nativePath -PathType Leaf

    return ($hasManaged -and $hasNative)
}

Export-ModuleMember -Function Test-SqliteDotNetInstalled