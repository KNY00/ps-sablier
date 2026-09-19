# Helper script providing database setup and teardown helpers for Pester suites
# Relies directly on src\Assets\schema.sql to avoid duplicating schema definitions.

function Initialize-TestDatabaseEnvironment {
    [CmdletBinding()]
    param ()

    # Resolve project root and module paths
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    $modulesDir = Join-Path $projectRoot "modules"

    # Add modules directory to current session PSModulePath
    $currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    if ($modulesDir -notin $currentPaths) {
        $env:PSModulePath = "$modulesDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    }

    # Import required backend modules
    Import-Module SQLiteLoader -Force -ErrorAction Stop
    Import-Module UiNotificationUtils -Force -ErrorAction Stop
    Import-Module SqliteUtils -Force -ErrorAction Stop

    # Ensure SQLite driver engine is initialized
    Initialize-SqliteDriver | Out-Null

    # Locate official project schema file in src\Assets
    $schemaPath = Join-Path $projectRoot "src\Assets\schema.sql"
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        throw "Official schema file not found at '$schemaPath'."
    }

    # Read the canonical SQL schema definition
    $schemaQuery = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($schemaQuery)) {
        throw "Official schema file at '$schemaPath' is empty."
    }

    # Generate isolated temporary database file
    $testDbPath = Join-Path $env:TEMP "sablier_test_$([System.Guid]::NewGuid().ToString('N')).sqlite"

    # Apply official schema directly through Invoke-SqliteWrapper
    $initialized = Invoke-SqliteWrapper -Query $schemaQuery -DatabasePath $testDbPath
    if (-not $initialized) {
        throw "Failed to initialize test database at: $testDbPath"
    }

    return $testDbPath
}

function Remove-TestDatabaseEnvironment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath
    )

    # Force garbage collection to release open SQLite connection handles
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # Safely remove temporary test database
    if (Test-Path -LiteralPath $DatabasePath) {
        Remove-Item -LiteralPath $DatabasePath -Force -ErrorAction SilentlyContinue
    }
}