<#
.SYNOPSIS
    Prompts the user for session notes or descriptions with Escape cancellation support.

.DESCRIPTION
    Encapsulates session description inputs. Serves as a single entrypoint
    that can be extended in future commits for validation, modification,
    or processing by external third-party tools.

.PARAMETER InitialDescription
    Optional draft description entered before session timer execution.

.OUTPUTS
    [string] The final confirmed or edited description, or $null if aborted.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$InitialDescription = ""
)

Import-Module SessionUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

# Future third-party preprocessing or analysis hooks can be plugged in here

if ([string]::IsNullOrWhiteSpace($InitialDescription)) {
    # Direct prompt when no initial draft was supplied
    return (Read-SessionNotes -CurrentNotes "")
}

# Display draft and prompt user to confirm, edit or discard
Show-InfoMessage "Initial session draft: '$InitialDescription'"
$finalDescription = Read-SessionNotes -CurrentNotes $InitialDescription

# Future third-party post-processing or analysis hooks can be plugged in here

return $finalDescription