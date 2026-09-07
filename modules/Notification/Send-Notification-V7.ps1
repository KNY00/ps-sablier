<#
.SYNOPSIS
    Sends a system notification and plays an audio alert when a session ends (PowerShell 7+ compatible).

.DESCRIPTION
    Constructs the toast payload and delegates display to the native Windows PowerShell host.
    Assets are passed through parameters.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$Title = "Session Timer",

    [Parameter(Mandatory = $false)]
    [string]$Message = "Session is over!",

    [Parameter(Mandatory = $false)]
    [string]$IconPath,

    [Parameter(Mandatory = $false)]
    [string]$SoundPath
)

# Prepare icon XML if file was specified and exists
$imageTag = ""
if (-not [string]::IsNullOrWhiteSpace($IconPath) -and (Test-Path -Path $IconPath)) {
    $resolvedIcon = (Resolve-Path -Path $IconPath).Path
    $imageUri = [System.Uri]::new($resolvedIcon).AbsoluteUri
    $imageTag = "<image placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$imageUri`"/>"
}

# Escape XML content to prevent malformed XML errors
$xmlEscapedTitle = [System.Security.SecurityElement]::Escape($Title)
$xmlEscapedMessage = [System.Security.SecurityElement]::Escape($Message)

$toastXml = @"
<toast duration="short">
    <visual>
        <binding template="ToastGeneric">
            <text>$xmlEscapedTitle</text>
            <text>$xmlEscapedMessage</text>
            $imageTag
        </binding>
    </visual>
    <audio silent="true"/>
</toast>
"@

try {
    # Script block to execute in Windows PowerShell 5.1 where WinRT is natively supported
    $winRtRunner = @"
`$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
`$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

`$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
`$xml.LoadXml(@'
$toastXml
'@)

`$toast = [Windows.UI.Notifications.ToastNotification]::new(`$xml)
`$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Microsoft.Windows.Explorer')
`$notifier.Show(`$toast)
"@

    # Encode script into Unicode Base64 to avoid quoting and escaping issues in CLI arguments
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($winRtRunner))

    # Trigger notification asynchronously in a hidden process
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", $encodedCommand `
        -WindowStyle Hidden
}
catch {
    Write-Warning "Could not display toast notification in PS7: $_"
}

# Play sound alert via companion script using provided SoundPath
$playSoundScript = Join-Path $PSScriptRoot "Play-SoundAlert.ps1"
if (Test-Path -Path $playSoundScript) {
    & $playSoundScript -SoundPath $SoundPath
}

# Display visual feedback in the terminal console
Write-Host "[!] $Title : $Message" -ForegroundColor Yellow