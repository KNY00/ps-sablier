<#
.SYNOPSIS
    Displays an interactive ASCII startup animation for ps-sablier with a post-animation delay.

.DESCRIPTION
    Renders an ASCII hourglass/clock animation line-by-line with smooth
    color transitions, displays a launch message, and pauses for a short duration
    before launching the main menu. Any keypress instantly skips the delay.
#>

[CmdletBinding()]
param (
    # Speed of line-by-line drawing
    [Parameter(Mandatory = $false)]
    [int]$DelayMilliseconds = 30,

    # Time to wait after the animation completes before loading the app
    [Parameter(Mandatory = $false)]
    [double]$HoldDurationSeconds = 2.0
)

# Raw ASCII art definition
$asciiArt = @(
    "       _yg@@@@@@@@@@@@@@@@@@gy_       ",
    "     y@@@@@@@@@P~  `~~~@@@@@@@@@y     ",
    "    z@@@@@@@@@y        7@@@@@@@@@%    ",
    "    @@@@@@@@@@@_       g@@@@@@@@@@    ",
    "    @@@@@@@@@@@$      g@@@@@@@@@@@    ",
    "    @@@@@@@@@@@@@    y@@@@@@@@@@@@    ",
    "    @@@@@@@@@@@@@y  y@@@@@@@@@@@@@    ",
    "    @@@@@@@@@@@@@@  @@@@@@@@@@@@@@    ",
    "    @@@@@@@@@@@@@F  @@@@@@@@@@@@@@    ",
    "    @@@@@@@@@@@@F    @@@@@@@@@@@@@    ",
    "    @@@@@@@@@@@F     `"@@@@@@@@@@@@    ",
    "    @@@@@@@@@@B       ^@@@@@@@@@@@    ",
    "    4@@@@@@@@@y        4@@@@@@@@@F    ",
    "     ~@@@@@@@@@yy__  ya@@@@@@@@@F     ",
    "       ~?R@@@@@@@@@@@@@@@@@@PF~       "
)

# Non-interactive console fallback
if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
    foreach ($line in $asciiArt) {
        Write-Host $line -ForegroundColor Cyan
    }
    return
}

# Preserve previous cursor state and hide cursor during animation
$originalCursorVisible = [Console]::CursorVisible
[Console]::CursorVisible = $false

try {
    Clear-Host

    # Render ASCII art row by row with progressive color grading
    $colorPalette = @('DarkCyan', 'Cyan', 'Cyan', 'White', 'White', 'Cyan', 'Cyan', 'DarkCyan')
    $totalLines = $asciiArt.Count

    for ($i = 0; $i -lt $totalLines; $i++) {
        # Check if user pressed a key to skip drawing
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            for ($k = $i; $k -lt $totalLines; $k++) {
                Write-Host $asciiArt[$k] -ForegroundColor Cyan
            }
            break
        }

        # Determine line color
        $colorIndex = [Math]::Min($colorPalette.Length - 1, [int](($i / $totalLines) * $colorPalette.Length))
        $lineColor = $colorPalette[$colorIndex]

        Write-Host $asciiArt[$i] -ForegroundColor $lineColor
        Start-Sleep -Milliseconds $DelayMilliseconds
    }

    # Display branding and loading notice
    Write-Host ""
    Write-Host "    >>> ps-sablier | Focus & Time Tracker <<<    " -ForegroundColor Yellow
    Write-Host "                Starting up...                   " -ForegroundColor DarkGray

    # Configurable post-animation pause (check every 50ms to allow instant skip)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $targetMillis = [int]($HoldDurationSeconds * 1000)

    while ($stopwatch.ElapsedMilliseconds -lt $targetMillis) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            break
        }
        Start-Sleep -Milliseconds 50
    }
    $stopwatch.Stop()

    # Clear input buffer before handing control over to the menu
    while ([Console]::KeyAvailable) {
        $null = [Console]::ReadKey($true)
    }
}
finally {
    # Restore cursor visibility
    [Console]::CursorVisible = $originalCursorVisible
}