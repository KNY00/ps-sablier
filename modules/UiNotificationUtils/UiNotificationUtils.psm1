# UiNotificationUtils.psm1
# User-friendly CLI feedback utilities using standard PowerShell streams.

# ANSI escape codes for cross-version terminal formatting (PS 5.1 & PS 7+)
$script:Esc       = [char]27
$script:Reset     = "$($script:Esc)[0m"
$script:Red       = "$($script:Esc)[31m"
$script:Green     = "$($script:Esc)[32m"
$script:Yellow    = "$($script:Esc)[33m"
$script:Cyan      = "$($script:Esc)[36m"
$script:DarkRedBg = "$($script:Esc)[97;41m"
$script:DarkGray  = "$($script:Esc)[90m"

# Safe cross-version symbols (avoids CP1252 / UTF-8 without BOM parsing issues on PS 5.1)
$script:SymbolCross = [char]0x2716
$script:SymbolCheck = [char]0x2713
$script:StrCheck    = "[$script:SymbolCheck]"
$script:StrCross    = "[$script:SymbolCross]"

<#
.SYNOPSIS
    Displays a formatted error message using standard error/information streams.

.PARAMETER Message
    The primary error description.

.PARAMETER Details
    Optional extra details or exception messages.

.PARAMETER Block
    If specified, displays a high-visibility background banner.
#>
function Show-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Details = $null,

        [Parameter(Mandatory = $false)]
        [switch]$Block
    )

    if ($Block) {
        $banner = " [ERROR] $Message "
        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            $banner += "`n   Details: $Details"
        }
        $formatted = "`n$($script:DarkRedBg)$banner$($script:Reset)`n"
    } else {
        $formatted = "$($script:Red)($script:StrCross) Error: $Message$($script:Reset)"
        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            $formatted += "`n  $($script:DarkGray)$Details$($script:Reset)"
        }
    }

    # Use standard custom tags without the reserved 'PS' prefix
    Write-Information -MessageData $formatted -InformationAction Continue -Tags 'UI', 'Error'
}

<#
.SYNOPSIS
    Displays a formatted warning message using PowerShell warning stream.

.PARAMETER Message
    The warning text.
#>
function Show-WarningMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    # Route to Stream 3 (Warning stream), natively suppressible and redirectable
    Write-Warning "$Message"
}

<#
.SYNOPSIS
    Displays a formatted success message.

.PARAMETER Message
    The success text.
#>
function Show-SuccessMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    $formatted = "$($script:Green)$($script:StrCheck) $Message$($script:Reset)"
    Write-Information -MessageData $formatted -InformationAction Continue -Tags 'UI', 'Success'
}

<#
.SYNOPSIS
    Displays a formatted informational message.

.PARAMETER Message
    The informational text.
#>
function Show-InfoMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    $formatted = "$($script:Cyan)[i] $Message$($script:Reset)"
    Write-Information -MessageData $formatted -InformationAction Continue -Tags 'UI', 'Info'
}

# Export utility functions
Export-ModuleMember -Function `
    Show-ErrorMessage, `
    Show-WarningMessage, `
    Show-SuccessMessage, `
    Show-InfoMessage