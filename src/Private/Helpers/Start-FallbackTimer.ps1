[CmdletBinding()]
param (
    # Duration string matching external timer format (e.g., 5s, 8m, 13h, 1h30m)
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Duration = "25m",

    # Display name of the active session
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$SessionName = "Session",

    # Path used to store session metadata (unified with Start-Timer.ps1)
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResultFile = "$env:TEMP\timer_result.json"
)

<#
.SYNOPSIS
    Parses a duration string (e.g. 5s, 8m, 13h, 1h30m45s) into total seconds.
#>
function Convert-DurationToSeconds {
    [CmdletBinding()]
    [OutputType([double])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DurationString
    )

    $trimmed = $DurationString.Trim().ToLower()

    # Match compound duration tokens (e.g., 1h30m, 8m, 45s)
    $strMatches = [regex]::Matches($trimmed, '(\d+(?:\.\d+)?)\s*([smhd])')
    
    if ($strMatches.Count -gt 0) {
        $totalSeconds = 0.0
        foreach ($match in $strMatches) {
            $value = [double]::Parse($match.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
            $unit = $match.Groups[2].Value

            switch ($unit) {
                's' { $totalSeconds += $value }
                'm' { $totalSeconds += ($value * 60) }
                'h' { $totalSeconds += ($value * 3600) }
                'd' { $totalSeconds += ($value * 86400) }
            }
        }
        return [math]::Max(1.0, $totalSeconds)
    }

    # Fallback if a plain numeric value without unit was entered (default to minutes)
    $parsedNum = 0.0
    if ([double]::TryParse($trimmed, [ref]$parsedNum) -and $parsedNum -gt 0) {
        return ($parsedNum * 60)
    }

    # Fallback to default 25 minutes if input cannot be parsed
    return (25 * 60)
}

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

    # Use hex codes for V7 to ensure the PS 5.1 parser does not crash on UTF-8 without BOM
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $sandPhases = @(
            ' ', 
            '.', 
            ':', 
            [string][char]0x2591, 
            [string][char]0x2592, 
            [string][char]0x2593, 
            [string][char]0x2588
        )
    } else {
        # Simplified ASCII UI for PowerShell 5.1
        $sandPhases = @(' ', '-', '~', '=', '#')
    }
    
    $phasesCount = $sandPhases.Count - 1
    $totalStates = $TotalWidth * $phasesCount

    # Clamp progress ratio between 0.0 and 1.0
    $clampedRatio = [math]::Max(0.0, [math]::Min(1.0, $ProgressRatio))
    $currentState = [int][math]::Round($clampedRatio * $totalStates)
    $percent = [int][math]::Round($clampedRatio * 100)

    $completedBlocks = [math]::Floor($currentState / $phasesCount)
    $phaseIndex = $currentState % $phasesCount

    if ($completedBlocks -ge $TotalWidth) {
        $solidString = [string]$sandPhases[-1] * $TotalWidth
        return "[$solidString] 100%"
    }

    $solidString = [string]$sandPhases[-1] * $completedBlocks
    $activeChar = [string]$sandPhases[$phaseIndex]
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
    Supports cancellation via the Escape key.
#>
function Show-SandLoadingBar {
    [CmdletBinding()]
    [OutputType([bool])]
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

    $cancelled = $false

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
            # Check for Escape key press
            while ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq [ConsoleKey]::Escape) {
                    $cancelled = $true
                    break
                }
            }

            if ($cancelled) {
                break
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
            while ($stopwatch.ElapsedMilliseconds -lt $nextTickMs) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq [ConsoleKey]::Escape) {
                        $cancelled = $true
                        break
                    }
                }
                Start-Sleep -Milliseconds 50
            }

            if ($cancelled) {
                break
            }
        }

        # Safe cursor positioning below rendered area upon exit
        Set-SafeCursorPosition -Left 0 -Top ($startTop + 2)
        Write-Host ""
        
        if ($cancelled) {
            Write-Host "Timer cancelled." -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "Loading Complete!"
            return $true
        }
    }
    finally {
        while ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
        }
        [Console]::CursorVisible = $originalCursorVisible
    }
}

# Resolve target duration in seconds from the input string
$totalDurationSeconds = Convert-DurationToSeconds -DurationString $Duration

# Record session start time
$SessionStart = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# Execute countdown bar
$completed = Show-SandLoadingBar -DurationSeconds $totalDurationSeconds -SessionName $SessionName

# Only persist and export session data if the timer ran to completion
if ($completed) {
    # Record session end time
    $SessionEnd = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    # Export session metadata to shared JSON file
    if (-not [string]::IsNullOrWhiteSpace($ResultFile)) {
        [PSCustomObject]@{
            StartedAt   = $SessionStart
            EndedAt     = $SessionEnd
            IsCompleted = 1
        } | ConvertTo-Json -Compress | Set-Content -Path $ResultFile -Encoding UTF8
    }
}