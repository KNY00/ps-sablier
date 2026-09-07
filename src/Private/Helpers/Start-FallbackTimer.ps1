[CmdletBinding()]
param (
    # Total duration of the countdown in seconds (default: 10s)
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateRange(1, [double]::MaxValue)]
    [double]$DurationSeconds = 10,

    # Display name of the active session
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$SessionName = "Session"
)

<#
.SYNOPSIS
    Formats the top header line displaying session start time and remaining countdown.
#>
function Format-SessionHeader {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $true)]
        [string]$SessionName,

        [Parameter(Mandatory = $true)]
        [timespan]$RemainingTime
    )

    $startStr = $StartTime.ToString("HH:mm")
    $remainingSeconds = [math]::Max(0, [int][math]::Ceiling($RemainingTime.TotalSeconds))
    $countdownSpan = [timespan]::FromSeconds($remainingSeconds)
    $countdownStr = "{0:D2}:{1:D2}:{2:D2}" -f ([int]$countdownSpan.TotalHours), $countdownSpan.Minutes, $countdownSpan.Seconds

    return "[$startStr] $SessionName - [$countdownStr]"
}

<#
.SYNOPSIS
    Builds the textual representation of the sand progress bar based on elapsed progress ratio.
#>
function Get-SandProgressBar {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [double]$ProgressRatio,

        [Parameter(Mandatory = $false)]
        [int]$TotalWidth = 60
    )

    $sandPhases = @(' ', '.', ':', '░', '▒', '▓', '█')
    $phasesCount = $sandPhases.Count - 1
    $totalStates = $TotalWidth * $phasesCount

    # Clamp progress ratio between 0.0 and 1.0
    $clampedRatio = [math]::Max(0.0, [math]::Min(1.0, $ProgressRatio))
    $currentState = [int][math]::Round($clampedRatio * $totalStates)
    $percent = [int][math]::Round($clampedRatio * 100)

    $completedBlocks = [math]::Floor($currentState / $phasesCount)
    $phaseIndex = $currentState % $phasesCount

    if ($completedBlocks -ge $TotalWidth) {
        $solidString = $sandPhases[-1] * $TotalWidth
        return "[$solidString] 100%"
    }

    $solidString = $sandPhases[-1] * $completedBlocks
    $activeChar = $sandPhases[$phaseIndex]
    $remainder = [math]::Max(0, $TotalWidth - $completedBlocks - 1)
    $emptyString = " " * $remainder

    return "[$solidString$activeChar$emptyString] $percent%"
}

<#
.SYNOPSIS
    Safely sets the console cursor position clamped within buffer boundaries.
#>
function Set-SafeCursorPosition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$Left,

        [Parameter(Mandatory = $true)]
        [int]$Top
    )

    $maxTop = [math]::Max(0, [Console]::BufferHeight - 1)
    $maxLeft = [math]::Max(0, [Console]::BufferWidth - 1)

    $clampedTop = [math]::Max(0, [math]::Min($Top, $maxTop))
    $clampedLeft = [math]::Max(0, [math]::Min($Left, $maxLeft))

    [Console]::SetCursorPosition($clampedLeft, $clampedTop)
}

<#
.SYNOPSIS
    Renders both the header line and the progress bar line at clamped cursor positions.
#>
function Render-SessionDisplay {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$StartTop,

        [Parameter(Mandatory = $true)]
        [string]$HeaderLine,

        [Parameter(Mandatory = $true)]
        [string]$BarLine
    )

    $bufferWidth = [Console]::BufferWidth

    # Render header line
    Set-SafeCursorPosition -Left 0 -Top $StartTop
    Write-Host ($HeaderLine.PadRight([math]::Max(0, $bufferWidth - 1))) -NoNewline

    # Render sand bar line
    Set-SafeCursorPosition -Left 0 -Top ($StartTop + 1)
    Write-Host ($BarLine.PadRight([math]::Max(0, $bufferWidth - 1))) -NoNewline
}

<#
.SYNOPSIS
    Runs the countdown timer updating both header and progress bar once every second.
#>
function Show-SandLoadingBar {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateRange(1, [double]::MaxValue)]
        [double]$DurationSeconds = 10,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SessionName = "Session"
    )

    $sessionStartTime = Get-Date
    $originalCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    try {
        $totalWidth = 60
        $totalSeconds = [int][math]::Ceiling($DurationSeconds)

        # Reserve 2 rows in the console buffer to prevent scroll shifts
        $currentTop = [Console]::CursorTop
        if ($currentTop + 2 -ge [Console]::BufferHeight) {
            Write-Host "`n`n"
            $currentTop = [Console]::BufferHeight - 3
        }
        $startTop = [math]::Max(0, $currentTop)

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Update loop executing once every second
        for ($sec = 0; $sec -le $totalSeconds; $sec++) {
            # Discard any buffered keystrokes
            while ([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
            }

            $remainingSeconds = [math]::Max(0, $totalSeconds - $sec)
            $remainingTime = [timespan]::FromSeconds($remainingSeconds)
            $ratio = $sec / $totalSeconds

            $headerText = Format-SessionHeader -StartTime $sessionStartTime -SessionName $SessionName -RemainingTime $remainingTime
            $barText = Get-SandProgressBar -ProgressRatio $ratio -TotalWidth $totalWidth

            Render-SessionDisplay -StartTop $startTop -HeaderLine $headerText -BarLine $barText

            if ($sec -eq $totalSeconds) {
                break
            }

            # Pace to the next second boundary taking elapsed time into account
            $nextTickMs = ($sec + 1) * 1000
            $sleepMs = [int]($nextTickMs - $stopwatch.ElapsedMilliseconds)

            if ($sleepMs -gt 0) {
                Start-Sleep -Milliseconds $sleepMs
            }
        }

        # Safe cursor positioning below rendered area upon completion
        Set-SafeCursorPosition -Left 0 -Top ($startTop + 2)
        Write-Host ""
        Write-Host "Loading Complete!"
    }
    finally {
        while ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
        }
        [Console]::CursorVisible = $originalCursorVisible
    }
}

# Execute countdown bar
Show-SandLoadingBar -DurationSeconds $DurationSeconds -SessionName $SessionName