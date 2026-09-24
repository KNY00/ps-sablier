# Register modules directory in PSModulePath
$ModulesDir = Join-Path $PSScriptRoot "modules"
$currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
if ($ModulesDir -notin $currentPaths) {
    $env:PSModulePath = "$ModulesDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
}

# Prepend tools/bin directory to PATH so timer.exe is discoverable
$ToolsBinDir = Join-Path $PSScriptRoot "tools\bin"
$currentEnvPaths = $env:PATH -split [System.IO.Path]::PathSeparator
if ($ToolsBinDir -notin $currentEnvPaths) {
    $env:PATH = "$ToolsBinDir$([System.IO.Path]::PathSeparator)$env:PATH"
}

# Verify that SQLite backend and driver are available and usable without downloading
Import-Module CheckDependencies -ErrorAction Stop
Test-SqliteAvailable | Out-Null

& ".\tools\Initialize-Database.ps1"

Show-InfoMessage "Initialize secret key registration service"

# Initialize Secret Management vault for API Keys
Import-Module SecretKeyService -ErrorAction SilentlyContinue
if (Get-Command -Name "Initialize-SecretVaultService" -ErrorAction SilentlyContinue) {
    Initialize-SecretVaultService
}

# Check if timer binary is already available in PATH
$timerAvailable = [bool](Get-Command -Name "timer" -CommandType Application -ErrorAction SilentlyContinue)

if (-not $timerAvailable) {
    Show-InfoMessage "Optional Component: External timer binary (timer.exe)."
    Show-WarningMessage "SECURITY NOTICE: Downloading third-party binaries from the web can present security risks."
    Show-InfoMessage "This download is completely OPTIONAL. The application includes a built-in fallback sand timer that works out of the box."

    $shouldDownload = Confirm-Action -Message "Do you wish to download the external timer anyway?"
    if ($shouldDownload) {
        & ".\tools\Install-Timer.ps1"
        Set-UserSetting -UseExternalTimer $true
        Show-SuccessMessage "External timer downloaded and enabled in settings."
    } else {
        Set-UserSetting -UseExternalTimer $false
        Show-InfoMessage "Skipping external timer download. Using built-in fallback timer."
    }
}

try {
    Test-ProjectPrerequisite
    Write-Host 'Up and Running!'
}
catch {
    Write-Error "Bootstrap failed: $_"
}