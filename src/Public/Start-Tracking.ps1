<#
.SYNOPSIS
    Starts an interactive time tracking or Pomodoro session.

.DESCRIPTION
    Prompts the user to select between a standard Pomodoro session or free tracking,
    runs the countdown timer or stopwatch, triggers notification alerts, and initiates
    session persistence and task-linking workflows.

.EXAMPLE
    .\Start-Tracking.ps1
#>

Import-Module CheckDependencies -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

Test-ProjectPrerequisite

$options = @("session", "free")

$TrackMode = Show-Menu -Title "How would like to track your time:" -Options $options
Show-SuccessMessage "Selected: $TrackMode"

$tempResult = "$env:TEMP\timer_session_$([System.Guid]::NewGuid().ToString('N')).json"

if ($TrackMode -eq 'session') {
	$inputDuration = Read-Host "Enter timer duration (e.g., 10m, 1h) [Default: 25m]"

    # Prompt for input, falling back to '25m' if left blank
	if ([string]::IsNullOrWhiteSpace($inputDuration)) {
		$inputDuration = "25m"
	}

    # Execute timer directly so the interactive bar renders cleanly to the terminal
	& "$PSScriptRoot\..\Private\Helpers\Start-Timer.ps1" -Duration $inputDuration -ResultFile $tempResult
} elseif ($TrackMode -eq "free") {
	# Execute timer directly so the interactive bar renders cleanly to the terminal
	& "$PSScriptRoot\..\Private\Helpers\Start-TimeTracking.ps1" -ResultFile $tempResult
} else {
    Remove-Item -Path $tempResult -Force -ErrorAction SilentlyContinue
    Write-Host "Session aborted."
    return
}

Write-Host ""

# Read and parse the JSON payload
$data = $null
if (Test-Path $tempResult) {
    try {
        $data = Get-Content -Path $tempResult -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Show-ErrorMessage "Failed to read timer session result: $_"
    }
    finally {
        Remove-Item -Path $tempResult -Force -ErrorAction SilentlyContinue
    }
}

# Validate that session data exists before dispatching notifications and invoking persistence workflow
if ($null -ne $data) {
    & "$PSScriptRoot\..\Private\Helpers\Show-Notification.ps1"

    # Execute the externalized session creation and task linking workflow
    & "$PSScriptRoot\..\Private\Helpers\Invoke-SessionCreationWorkflow.ps1" -SessionData $data
} else {
    Show-InfoMessage "Session tracking was cancelled or did not produce session data."
}