<#
.SYNOPSIS
    Module entrypoint for dispatching notifications across PowerShell 5.1 and 7+.
#>

function Send-Notification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Title = "Session Timer",

        [Parameter(Mandatory = $false)]
        [string]$Message = "Your session has ended! Take a break or move to your next task.",

        [Parameter(Mandatory = $false)]
        [string]$IconPath,

        [Parameter(Mandatory = $false)]
        [string]$SoundPath
    )

    # Determine default paths from project structure if not provided
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    if ([string]::IsNullOrWhiteSpace($IconPath)) {
        $IconPath = Join-Path $ProjectRoot "src\Assets\notification-icon.png"
    }

    # Route execution based on active PowerShell major version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $targetScript = Join-Path $PSScriptRoot "Send-Notification-V7.ps1"
        & $targetScript -Title $Title -Message $Message -IconPath $IconPath -SoundPath $SoundPath
    }
    else {
        $targetScript = Join-Path $PSScriptRoot "Send-Notification-V5.ps1"
        & $targetScript -Title $Title -Message $Message -IconPath $IconPath -SoundPath $SoundPath
    }
}

Export-ModuleMember -Function Send-Notification