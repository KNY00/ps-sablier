# Import shared modules
Import-Module CheckDependencies -ErrorAction Stop
Import-Module SqliteInstaller -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

Initialize-ProjectEnvironment

# Check if .NET SQLite libraries are present
if (Test-SqliteDotNetInstalled) {
    Show-SuccessMessage "A functional .NET SQLite backend is already configured."
    return
}

Show-ErrorMessage "Embedded .NET SQLite binaries not detected in 'modules\SQLiteLoader\runtimes'."
Write-Host "Automatic downloads are disabled. Please provide the required assemblies manually." -ForegroundColor Yellow
exit 1