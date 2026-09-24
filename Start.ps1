<#
.SYNOPSIS
    Main CLI entrypoint for ps-sablier.

.DESCRIPTION
    Controls and launches public scripts located in src/Public with pre-flight
    dependency checks and interactive navigation.
#>

[CmdletBinding()]
param ()

# Resolve the root directory of the project
$ProjectRoot = $PSScriptRoot

# Register modules root directory into PSModulePath if not already present
$ModulesDir = Join-Path $ProjectRoot "modules"
$currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
if ($ModulesDir -notin $currentPaths) {
    $env:PSModulePath = "$ModulesDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
}

# Prepend tools/bin directory to PATH so timer.exe is discoverable
$ToolsBinDir = Join-Path $ProjectRoot "tools\bin"
$currentEnvPaths = $env:PATH -split [System.IO.Path]::PathSeparator
if ($ToolsBinDir -notin $currentEnvPaths) {
    $env:PATH = "$ToolsBinDir$([System.IO.Path]::PathSeparator)$env:PATH"
}

# Import required modules directly by name
Import-Module CheckDependencies -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop
Import-Module UserSettings -ErrorAction Stop

# Verify prerequisites (SQLite backend and timer executable)
Test-ProjectPrerequisite

# Intro Animation (conditionally skipped based on user settings)
$skipIntro = Get-UserSkipIntro
if (-not $skipIntro) {
    $introScript = Join-Path $ProjectRoot "src\Private\Helpers\Show-IntroAnimation.ps1"
    if (Test-Path -Path $introScript) {
        & $introScript
    }
}

# Define absolute paths to public scripts
$publicScriptsDir = Join-Path $ProjectRoot "src\Public"

$scriptTracking = Join-Path $publicScriptsDir "Start-Tracking.ps1"
$scriptTasks    = Join-Path $publicScriptsDir "Invoke-TaskManager.ps1"
$scriptSessions = Join-Path $publicScriptsDir "Invoke-SessionManager.ps1"
$scriptAgent    = Join-Path $publicScriptsDir "Invoke-AskAgent.ps1"
$scriptSettings = Join-Path $publicScriptsDir "Invoke-SettingsManager.ps1"

# Menu configuration conforming to specifications:
$menuOptions = @(
    "Start Tracking",
    "Task Manager",
    "Session Manager",
    "Ask Agent",
    "Settings",
    "Exit"
)

while ($true) {
    Clear-Host
    $selection = Show-Menu -Title "=== Home ===" -Options $menuOptions

    # Handle Escape key press or null return
    if ([string]::IsNullOrWhiteSpace($selection) -or $selection -eq "Exit") {
        Write-Host "Goodbye!" -ForegroundColor Yellow
        break
    }

    switch ($selection) {
        "Start Tracking" {
            if (Test-Path -Path $scriptTracking) {
                & $scriptTracking
            } else {
                Show-ErrorMessage "Script not found at '$scriptTracking'."
            }
            Pause
        }

        "Task Manager" {
            if (Test-Path -Path $scriptTasks) {
                & $scriptTasks
            } else {
                Show-ErrorMessage "Script not found at '$scriptTasks'."
            }
        }

        "Session Manager" {
            if (Test-Path -Path $scriptSessions) {
                & $scriptSessions
            } else {
                Show-ErrorMessage "Script not found at '$scriptSessions'."
            }
        }
        
        "Ask Agent" {
            if (Test-Path -Path $scriptAgent) {
                & $scriptAgent
            } else {
                Show-ErrorMessage "Script not found at '$scriptAgent'."
            }
            Pause
        }

        "Settings" {
            if (Test-Path -Path $scriptSettings) {
                & $scriptSettings
            } else {
                Show-ErrorMessage "Script not found at '$scriptSettings'."
            }
        }
    }
}