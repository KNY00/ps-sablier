[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$SessionData,

    [Parameter(Mandatory = $false)]
    [string]$InitialDescription = ""
)

Import-Module SessionController -ErrorAction Stop
Import-Module SessionUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

# Prompt for session type with abort capability on Escape
$selectedType = Select-SessionType -AllowCancel
if ($null -eq $selectedType) {
    Show-InfoMessage "Session creation cancelled."
    return
}

# Delegate note acquisition and confirmation to the dedicated helper
$promptHelperPath = Join-Path $PSScriptRoot "Prompt-SessionDescription.ps1"

if (Test-Path -Path $promptHelperPath) {
    $notes = & $promptHelperPath -InitialDescription $InitialDescription
} else {
    $notes = Read-SessionNotes -CurrentNotes $InitialDescription
}

if ($null -eq $notes) {
    Show-InfoMessage "Session creation cancelled."
    return
}

# Insert into database directly via SessionController
$created = New-TimeSessionItem `
    -Type $selectedType `
    -StartedAt $SessionData.StartedAt `
    -EndedAt $SessionData.EndedAt `
    -IsCompleted $SessionData.IsCompleted `
    -Notes $notes

if (-not $created -or ($null -eq $created.Id -and $null -eq $created.id)) {
    Write-Error "Failed to record session in database."
    return
}

$sessionId = if ($null -ne $created.Id) { [long]$created.Id } else { [long]$created.id }
Show-SuccessMessage "Session #$sessionId created successfully."
Write-Host ""

# Offer task linking via shared utility
Invoke-TaskLinkingPrompt -SessionId $sessionId