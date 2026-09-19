<#
.SYNOPSIS
    Initializes the SQLite database using the external schema.sql file.

.DESCRIPTION
    Reads the schema.sql definition file and applies it to the project database
    via Invoke-SqliteWrapper. Supports both sqlite3 CLI and PSSQLite seamlessly.

.PARAMETER Force
    If specified, removes an existing database file before recreating it.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# Import shared modules
Import-Module CheckDependencies -ErrorAction Stop
Import-Module SqliteUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

# Verify SQLite backend availability directly
Test-SqliteAvailable

$DatabasePath = (Get-SqliteDatabasePath)
$SchemaPath   = (Join-Path $ProjectRoot "src\Assets\schema.sql")

# Validate that the schema file exists
if (-not (Test-Path -Path $SchemaPath -PathType Leaf)) {
    Show-ErrorMessage "Schema file not found at '$SchemaPath'."
    exit 1
}

# Handle Force switch to recreate database cleanly
if ($Force -and (Test-Path -Path $DatabasePath)) {
    Write-Host "Force switch detected. Removing existing database: $DatabasePath" -ForegroundColor Yellow
    Remove-Item -Path $DatabasePath -Force
}

# Ensure parent directory of the database exists
$DatabaseDirectory = Split-Path -Path $DatabasePath -Parent
if (-not [string]::IsNullOrWhiteSpace($DatabaseDirectory) -and -not (Test-Path -Path $DatabaseDirectory)) {
    New-Item -ItemType Directory -Path $DatabaseDirectory -Force | Out-Null
}

$ShortSchema = Split-Path -Path $SchemaPath -Leaf
$DB = Split-Path -Path $DatabasePath -Leaf
Write-Host "Applying schema from '$ShortSchema' to '$DB'..."

try {
    # Read schema SQL queries
    $schemaQuery = Get-Content -Path $SchemaPath -Raw -Encoding UTF8

    # Apply schema through unified wrapper
    $result = Invoke-SqliteWrapper -Query $schemaQuery -DatabasePath $DatabasePath

    if (-not $result) {
        throw "Invoke-SqliteWrapper returned a non-success status."
    }

    Show-SuccessMessage "Database successfully initialized at '$DatabasePath'."
}
catch {
    $e = $_.Exception
    while ($e.InnerException) {
        $e = $e.InnerException
        Write-Host "InnerException: $($e.GetType().FullName) - $($e.Message)" -ForegroundColor Yellow
    }
    Show-ErrorMessage "Failed to initialize database: $_"
    exit 1
}