<#
.SYNOPSIS
    Interactive CLI utility functions for date and time input.
#>

function Read-DateTimeInteractive {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param ()

    # Fallback if console manipulation is unsupported in current host
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        $now = Get-Date
        return [PSCustomObject]@{
            DateTime      = $now
            Formatted     = $now.ToString("yyyy-MM-dd HH:mm:ss")
            UnixTimestamp = [DateTimeOffset]::new($now).ToUnixTimeSeconds()
        }
    }

    # Reference time for default values
    $now = Get-Date

    # Helper function to capture keystrokes, support Up/Down arrows, and manual typing
    function Read-PartWithArrows {
        param (
            [string]$Name,
            [int]$InitialValue,
            [int]$Min,
            [int]$Max
        )

        $currentVal = $InitialValue
        $customBuffer = ""

        # Determine prompt prefix
        $promptPrefix = "Enter $Name [$Min-$Max]: "
        Write-Host -NoNewline $promptPrefix

        # Store cursor position for in-place re-rendering
        $cursorLeft = [Console]::CursorLeft
        $cursorTop  = [Console]::CursorTop

        # Render helper to redraw only the editable part
        $redraw = {
            [Console]::SetCursorPosition($cursorLeft, $cursorTop)
            $displayStr = if ($customBuffer.Length -gt 0) { $customBuffer } else { "$currentVal (Default)" }
            Write-Host -NoNewline ($displayStr.PadRight(18))
            [Console]::SetCursorPosition($cursorLeft + $displayStr.Length, $cursorTop)
        }

        & $redraw

        while ($true) {
            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                'UpArrow' {
                    $customBuffer = ""
                    $currentVal++
                    if ($currentVal -gt $Max) { $currentVal = $Min }
                    & $redraw
                }
                'DownArrow' {
                    $customBuffer = ""
                    $currentVal--
                    if ($currentVal -lt $Min) { $currentVal = $Max }
                    & $redraw
                }
                'Backspace' {
                    if ($customBuffer.Length -gt 0) {
                        $customBuffer = $customBuffer.Substring(0, $customBuffer.Length - 1)
                        & $redraw
                    }
                }
                'Enter' {
                    if ($customBuffer.Length -gt 0) {
                        $parsed = 0
                        if ([int]::TryParse($customBuffer, [ref]$parsed)) {
                            # Clamping compatible with .NET Framework (PS 5.1) and .NET Core (PS 7+)
                            $currentVal = [Math]::Max($Min, [Math]::Min($parsed, $Max))
                        }
                    }
                    Write-Host ""
                    return $currentVal
                }
                default {
                    if ([char]::IsDigit($keyInfo.KeyChar)) {
                        $customBuffer += $keyInfo.KeyChar
                        & $redraw
                    }
                }
            }
        }
    }

    # Prompt each date/time component
    $year   = Read-PartWithArrows -Name "Year"   -InitialValue $now.Year   -Min 1970 -Max 2100
    $month  = Read-PartWithArrows -Name "Month"  -InitialValue $now.Month  -Min 1    -Max 12
    
    # Dynamically clamp day limit based on the selected year and month
    $maxDaysInMonth = [DateTime]::DaysInMonth($year, $month)
    $clampedDay     = [Math]::Min($now.Day, $maxDaysInMonth)
    $day    = Read-PartWithArrows -Name "Day"    -InitialValue $clampedDay -Min 1    -Max $maxDaysInMonth

    $hour   = Read-PartWithArrows -Name "Hour"   -InitialValue $now.Hour   -Min 0    -Max 23
    $minute = Read-PartWithArrows -Name "Minute" -InitialValue $now.Minute -Min 0    -Max 59

    # Build DateTime and Unix timestamp (seconds)
    $TargetDateTime = [datetime]::new($year, $month, $day, $hour, $minute, 0)
    $unixTimestamp  = [DateTimeOffset]::new($TargetDateTime).ToUnixTimeSeconds()

    # Return structured object
    [PSCustomObject]@{
        DateTime      = $TargetDateTime
        Formatted     = $TargetDateTime.ToString("yyyy-MM-dd HH:mm:ss")
        UnixTimestamp = $unixTimestamp
    }
}

# Explicitly expose only the interactive reader function
Export-ModuleMember -Function Read-DateTimeInteractive