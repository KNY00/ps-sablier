# Resolve project root relative to this module directory
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Resolve default database path relative to project structure
$script:DatabasePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot "assets\db.sqlite"))

# Ensure SQLiteLoader is ready
if (-not (Get-Module -Name "SQLiteLoader")) {
    Import-Module SQLiteLoader -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
    Resolves and returns the full path to the SQLite database.
.DESCRIPTION
    Retrieves the path configured in $script:DatabasePath, attempting to resolve it 
    via Resolve-Path if it exists, or returning the fallback path.
.OUTPUTS
    [string] The absolute path to the SQLite database file.
#>
function Get-SqliteDatabasePath {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $resolved = (Resolve-Path -Path $script:DatabasePath -ErrorAction SilentlyContinue).Path
    if ($resolved) {
        return $resolved
    }
    return $script:DatabasePath
}

<#
.SYNOPSIS
    Validates that the SQLite database file exists at the specified path.
.DESCRIPTION
    Checks if the database file exists using Test-Path. If the file is missing, 
    displays an error message and returns $false.
.PARAMETER Path
    The path to the SQLite database. Defaults to the result of Get-SqliteDatabasePath.
.OUTPUTS
    [bool] Returns $true if the database exists, otherwise $false.
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
        return $false
    }
    return $true
}

<#
.SYNOPSIS
    Unified query execution wrapper relying exclusively on Microsoft.Data.Sqlite (.NET).
.DESCRIPTION
    Initializes the SQLite driver, opens a connection to the database, safely binds parameters,
    and executes either a non-query command or a query returning results (optionally as structured objects).
.PARAMETER Query
    The SQL query or statement to execute.
.PARAMETER Parameters
    A hashtable or dictionary of parameters to bind to the SQL query. Parameter keys 
    automatically get prefixed with '@' if not already present.
.PARAMETER DatabasePath
    The path to the SQLite database file. Defaults to Get-SqliteDatabasePath.
.PARAMETER AsJson
    When specified, executes a reader, fetches all rows into ordered custom objects, and returns an array.
    When omitted, executes a non-query command and returns $true on success or $false on failure.
.OUTPUTS
    [object[]] An array of PSCustomObjects if -AsJson is specified.
    [bool] $true on successful non-query execution, or $false on error.
#>
function Invoke-SqliteWrapper {
    <#
    .SYNOPSIS
        Unified query execution wrapper relying exclusively on Microsoft.Data.Sqlite (.NET).
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

    # Initialize .NET driver if not active
    Initialize-SqliteDriver | Out-Null

    $connString = "Data Source=$DatabasePath"
    $connection = [Microsoft.Data.Sqlite.SqliteConnection]::new($connString)

    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query

        # Bind parameters safely
        if ($Parameters -and $Parameters.Count -gt 0) {
            foreach ($key in $Parameters.Keys) {
                $cleanKey = if ($key.StartsWith("@")) { $key } else { "@$key" }
                $val = $Parameters[$key]
                $dbVal = if ($null -eq $val) { [System.DBNull]::Value } else { $val }
                $null = $command.Parameters.AddWithValue($cleanKey, $dbVal)
            }
        }

        if ($AsJson) {
            $reader = $command.ExecuteReader()
            $rows = [System.Collections.Generic.List[PSObject]]::new()

            while ($reader.Read()) {
                $rowObj = [ordered]@{}
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    $fieldName = $reader.GetName($i)
                    $val = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                    $rowObj[$fieldName] = $val
                }
                $rows.Add([PSCustomObject]$rowObj)
            }
            $reader.Dispose()
            return @($rows)
        } else {
            $null = $command.ExecuteNonQuery()
            return $true
        }
    }
    catch {
        Show-ErrorMessage "SQLite .NET execution error: $_"
        if ($AsJson) {
            return @()
        }
        return $false
    }
    finally {
        if ($null -ne $command) { $command.Dispose() }
        if ($null -ne $connection) {
            $connection.Close()
            $connection.Dispose()
        }
    }
}

Export-ModuleMember -Function `
    Get-SqliteDatabasePath, `
    Assert-SqliteDatabasePath, `
    Invoke-SqliteWrapper