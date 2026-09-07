<#
.SYNOPSIS
    Displays a Windows toast notification and plays an audio alert for Windows PowerShell 5.1.

.DESCRIPTION
    Utilizes native WinRT APIs to construct and render a rich Windows Toast notification.
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

# Load WinRT types
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

# Prepare image XML tag only if IconPath is supplied and exists
$imageTag = ""
if (-not [string]::IsNullOrWhiteSpace($IconPath) -and (Test-Path -Path $IconPath)) {
    $resolvedIcon = (Resolve-Path -Path $IconPath).Path
    $imageUri = [System.Uri]::new($resolvedIcon).AbsoluteUri
    $imageTag = "<image placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$imageUri`"/>"
}

# Escape XML content to prevent malformed XML errors
$xmlEscapedTitle = [System.Security.SecurityElement]::Escape($Title)
$xmlEscapedMessage = [System.Security.SecurityElement]::Escape($Message)

$toastXmlString = @"
<toast duration="short">
    <visual>
        <binding template="ToastGeneric">
            <text>$xmlEscapedTitle</text>
            <text>$xmlEscapedMessage</text>
            $imageTag
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" silent="true"/>
</toast>
"@

$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
$xml.LoadXml($toastXmlString)

$appId = "Microsoft.Windows.Explorer"

$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)

# Show toast notification
$notifier.Show($toast)

# Play sound alert via companion script using provided SoundPath
$playSoundScript = Join-Path $PSScriptRoot "Play-SoundAlert.ps1"
if (Test-Path -Path $playSoundScript) {
    & $playSoundScript -SoundPath $SoundPath
}