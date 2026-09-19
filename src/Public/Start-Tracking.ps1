Import-Module CheckDependencies -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop
Import-Module UserSettings -ErrorAction Stop

Test-ProjectPrerequisite

$options = @("session", "free")

$TrackMode = Show-Menu -Title "How would like to track your time:" -Options $options
Show-SuccessMessage "Selected: $TrackMode"

# Shared transfer file used across external timer, fallback timer, and tracking modes
$tempResult = "$env:TEMP\timer_session_$([System.Guid]::NewGuid().ToString('N')).json"

if ($TrackMode -eq 'session') {
    $useExternal = Get-UserUseExternalTimer
    $timerExecutableAvailable = [bool](Get-Command -Name "timer" -CommandType Application -ErrorAction SilentlyContinue)

    # Prompt user with the same duration format (5s, 8m, 13h, etc.) for both timers
    $inputDuration = Read-Host "Enter timer duration (e.g., 5s, 8m, 13h, 25m) [Default: 25m]"
    if ([string]::IsNullOrWhiteSpace($inputDuration)) {
        $inputDuration = "25m"
    }

    if ($useExternal -and $timerExecutableAvailable) {
        & "$PSScriptRoot\..\Private\Helpers\Start-Timer.ps1" -Duration $inputDuration -ResultFile $tempResult
    }
    else {
        if ($useExternal -and -not $timerExecutableAvailable) {
            Show-WarningMessage "External timer binary 'timer.exe' is not found. Falling back to built-in sand timer."
        }

        # Fallback timer invoked with identical duration format and the shared result file
        & "$PSScriptRoot\..\Private\Helpers\Start-FallbackTimer.ps1" -Duration $inputDuration -SessionName "Pomodoro" -ResultFile $tempResult
    }
} elseif ($TrackMode -eq "free") {
    & "$PSScriptRoot\..\Private\Helpers\Start-TimeTracking.ps1" -ResultFile $tempResult
} else {
    Remove-Item -Path $tempResult -Force -ErrorAction SilentlyContinue
    Write-Host "Session aborted."
    return
}

Write-Host ""

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

if ($null -ne $data) {
    & "$PSScriptRoot\..\Private\Helpers\Show-Notification.ps1"
    & "$PSScriptRoot\..\Private\Helpers\Invoke-SessionCreationWorkflow.ps1" -SessionData $data
} else {
    Show-InfoMessage "Session tracking was cancelled or did not produce session data."
}