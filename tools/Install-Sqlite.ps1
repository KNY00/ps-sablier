# Import shared module by name
Import-Module CheckDependencies -ErrorAction Stop
Import-Module SqliteInstaller -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

# Pre-populate PATH with tools\bin if already populated
Initialize-ProjectEnvironment

try {
    $currentBackend = Test-SqliteAvailable
    Show-SuccessMessage "A functional SQLite backend ($currentBackend) is already configured."
    Show-InfoMessage "Skipping installation."
    
    if ($currentBackend -eq "CLI") {
        sqlite3 --version
    }
    return
}
catch {
    # Backend missing, proceed with installation flow
    Show-InfoMessage "No backend found."
}

# Target binary directory
$PathSqliteCli = Join-Path $PSScriptRoot "bin"

# Install to a target directory
Install-SqliteCli -FilePath $PathSqliteCli

# Add binary directory to PATH for the current session instance if not already present
Initialize-ProjectEnvironment

try {
    $resolvedBackend = Confirm-SqliteAvailable
    Show-SuccessMessage "SQLite backend successfully initialized using: $resolvedBackend"
}
catch {
    Show-ErrorMessage "Failed to configure any SQLite backend: $_"
    exit 1
}