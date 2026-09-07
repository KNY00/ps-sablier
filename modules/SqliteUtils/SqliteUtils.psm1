# Resolve project root relative to this module directory
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Resolve default database path relative to project structure
$script:DatabasePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot "assets\db.sqlite"))

function Get-SqliteDatabasePath {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $resolved = (Resolve-Path -Path $script:DatabasePath -ErrorAction SilentlyContinue).Path
    if ($resolved) {
        $resolved
        return
    }
    $script:DatabasePath
}

<#
.SYNOPSIS
    Validates whether the SQLite database file exists on disk.

.DESCRIPTION
    Checks the existence of the database file at the given path.
    Outputs an error message and returns $false if the file is absent, otherwise returns $true.

.PARAMETER Path
    The file path to the SQLite database. Defaults to the result of Get-SqliteDatabasePath.

.OUTPUTS
    [bool] True if the database file exists, false otherwise.

.EXAMPLE
    Assert-SqliteDatabasePath

.EXAMPLE
    Assert-SqliteDatabasePath -Path "assets/db.sqlite"
#>
function Assert-SqliteDatabasePath {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path = (Get-SqliteDatabasePath)
    )

    if (-not (Test-Path -Path $Path)) {
        Show-ErrorMessage "Database file '$Path' not found."
        $false
        return
    }
    $true
}

function Write-SqliteError {
    Show-ErrorMessage "No valid SQLite backend found. Please install sqlite3 or PSSQLite."
    Show-InfoMessage "Run ./bootstrap.ps1 to install dependencies."
    throw "Missing SQLite backend."
}

function Invoke-SqliteWrapper {
    <#
    .SYNOPSIS
        Unified query execution wrapper supporting both sqlite3 CLI and PSSQLite with parameter support.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath),

        [Parameter(Mandatory = $false)]
        [switch]$AsJson
    )

    $backend = Get-SqliteBackend

    if ($backend -eq "CLI") {
        # Securely interpolate parameters for SQLite CLI fallback
        $sanitizedQuery = $Query
        if ($Parameters -and $Parameters.Count -gt 0) {
            foreach ($key in $Parameters.Keys) {
                $val = $Parameters[$key]
                $paramName = if ($key.StartsWith("@")) { $key } else { "@$key" }
                
                $sqlLiteral = if ($null -eq $val -or $val -is [System.DBNull]) {
                    "NULL"
                } elseif ($val -is [bool]) {
                    if ($val) { "1" } else { "0" }
                } elseif ($val -is [byte] -or $val -is [int] -or $val -is [long] -or $val -is [double] -or $val -is [decimal]) {
                    "$val"
                } else {
                    "'" + ([string]$val).Replace("'", "''") + "'"
                }
                
                # Replace parameter token ensuring boundaries
                $pattern = [regex]::Escape($paramName) + '(?!\w)'
                $sanitizedQuery = [regex]::Replace($sanitizedQuery, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ $sqlLiteral })
            }
        }

        if ($AsJson) {
            $processOutput = & sqlite3 -json $DatabasePath $sanitizedQuery 2>&1
            if ($LASTEXITCODE -ne 0) {
                Show-ErrorMessage "SQLite CLI Error: $processOutput"
                @()
                return
            }
            if ($processOutput) {
                $rawJson = $processOutput -join "`n"
                $deserialized = $rawJson | ConvertFrom-Json
                @($deserialized)
                return
            }
            @()
            return
        } else {
            $null = & sqlite3 $DatabasePath $sanitizedQuery 2>&1
            ($LASTEXITCODE -eq 0)
            return
        }
    }
    elseif ($backend -eq "PSSQLite") {
        try {
            $invokeParams = @{
                DataSource  = $DatabasePath
                Query       = $Query
                ErrorAction = 'Stop'
            }

            if ($Parameters -and $Parameters.Count -gt 0) {
                # Format parameters for PSSQLite
                $queryParameters = @{}
                foreach ($key in $Parameters.Keys) {
                    $cleanKey = if ($key.StartsWith("@")) { $key.Substring(1) } else { $key }
                    $val = $Parameters[$key]
                    $queryParameters[$cleanKey] = if ($null -eq $val) { [System.DBNull]::Value } else { $val }
                }
                $invokeParams['QueryParameters'] = $queryParameters
            }

            $result = PSSQLite\Invoke-SqliteQuery @invokeParams

            if ($AsJson) {
                if ($null -eq $result) {
                    @()
                    return
                }
                @($result)
                return
            } else {
                $true
                return
            }
        }
        catch {
            Show-ErrorMessage "PSSQLite execution error: $_"
            $false
            return
        }
    } else {
        Write-SqliteError
    }
}

Export-ModuleMember -Function `
    Get-SqliteDatabasePath, `
    Assert-SqliteDatabasePath, `
    Invoke-SqliteWrapper