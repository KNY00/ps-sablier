<#
.SYNOPSIS
    Plays an audio alert for notifications.

.DESCRIPTION
    Plays a custom WAV sound file synchronously using System.Media.SoundPlayer.
    Falls back to system exclamation sound and console beep if unavailable or if path is invalid.

.PARAMETER SoundPath
    The absolute or relative path to the sound file provided by the caller.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SoundPath
)

# Only attempt custom audio playback if SoundPath was explicitly supplied and exists
if (-not [string]::IsNullOrWhiteSpace($SoundPath) -and (Test-Path -Path $SoundPath)) {
    try {
        $player = [System.Media.SoundPlayer]::new($SoundPath)
        # Block execution until playback finishes
        $player.PlaySync()
        $player.Dispose()
    }
    catch {
        # Fallback to system sound if sound player fails
        [System.Media.SystemSounds]::Exclamation.Play()
    }
}
else {
    try {
        # Fallback to system exclamation sound if file does not exist or was not specified
        [System.Media.SystemSounds]::Exclamation.Play()
    }
    catch {
        # Final fallback to standard console beep
        [Console]::Beep(800, 300)
    }
}