<#
.SYNOPSIS
    Runs an interactive stopwatch session and exports metadata upon exit.
#>
[CmdletBinding()]
param(
    # Initial session draft description
    [Parameter(Mandatory = $false)]
    [string]$DraftDescription = "",

    # Path used to store session metadata
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResultFile = "$env:TEMP\timer_result.json"
)

$startTime = [DateTime]::UtcNow

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$isPaused = $false

Write-Host "Controls: [Space] Pause/Resume | [Q] Stop/Exit`n" -ForegroundColor Cyan

try {
    while ($true) {
        # Check for user input without blocking the display
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key

            # Toggle pause on Spacebar
            if ($key -eq [ConsoleKey]::Spacebar) {
                if ($isPaused) {
                    $sw.Start()
                    $isPaused = $false
                } else {
                    $sw.Stop()
                    $isPaused = $true
                }
            }
            # Exit and finish on 'Q'
            elseif ($key -eq [ConsoleKey]::Q) {
                break
            }
        }

        # Build status indicator and update line
        $status = if ($isPaused) { "[PAUSED] " } else { "[RUNNING]" }
        $timeString = "{0:D2}h {1:D2}m {2:D2}s" -f $sw.Elapsed.Hours, $sw.Elapsed.Minutes, $sw.Elapsed.Seconds
        Write-Host -NoNewline ("`r$status Elapsed: $timeString   ")

        Start-Sleep -Milliseconds 150
    }
}
finally {
    # Ensure stopwatch is stopped and record final timestamp
    $sw.Stop()
    $endTime = [DateTime]::UtcNow
    Write-Host "`n"
}

# Return final output object with DraftDescription
[PSCustomObject]@{
    StartedAt        = [DateTimeOffset]::new($startTime).ToUnixTimeSeconds()
    EndedAt          = [DateTimeOffset]::new($endTime).ToUnixTimeSeconds()
    IsCompleted      = 1
    DraftDescription = $DraftDescription
} | ConvertTo-Json -Compress | Set-Content -Path $ResultFile -Encoding UTF8