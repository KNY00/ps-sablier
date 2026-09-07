<#
.SYNOPSIS
    Dispatches end-of-session desktop notifications and audio cues.
#>
[CmdletBinding()]
param()

Import-Module Notification -ErrorAction Stop
Import-Module UserSettings -ErrorAction Stop

$srcPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$iconPath = Join-Path $srcPath "Assets\notification-icon.png"
$soundPath = Get-UserSoundPath

if ($soundPath -is [string] -and -not [string]::IsNullOrWhiteSpace($soundPath)) {
    Send-Notification -IconPath $iconPath -SoundPath $soundPath
} else {
    Send-Notification -IconPath $iconPath
}