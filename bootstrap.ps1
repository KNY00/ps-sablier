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

& ".\tools\Install-Sqlite.ps1"

& ".\tools\Initialize-Database.ps1"

& ".\tools\Install-Timer.ps1"

try {
    Test-ProjectPrerequisite
    Write-Host 'Up and Running!'
}
catch {
    # Output error details if validation or command resolution fails
    Write-Error "Bootstrap failed: $_"
}
