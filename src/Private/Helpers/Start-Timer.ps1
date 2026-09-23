<#
.SYNOPSIS
    Runs an interactive countdown timer session and exports metadata.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Duration = "25m",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Name = "Session",

    # Initial session draft description
    [Parameter(Mandatory = $false)]
    [string]$DraftDescription = "",

    # Path used to store session metadata
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResultFile = "$env:TEMP\timer_result.json"
)

# Record session start time
$SessionStart = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# Run the external timer directly in the active console (preserves ANSI/TTY formatting)
& timer -n $Name $Duration

# Record session end time
$SessionEnd = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# Save metadata to disk with DraftDescription property
[PSCustomObject]@{
    StartedAt        = $SessionStart
    EndedAt          = $SessionEnd
    IsCompleted      = 1
    DraftDescription = $DraftDescription
} | ConvertTo-Json -Compress | Set-Content -Path $ResultFile -Encoding UTF8