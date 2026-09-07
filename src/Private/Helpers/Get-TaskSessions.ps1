[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [int]$TaskId
)

Import-Module TaskController -ErrorAction Stop

# Fetch task sessions via the controller
$sessions = Get-TaskSessionItems -TaskId $TaskId

if (-not $sessions -or $sessions.Count -eq 0) {
    Write-Host "No sessions found for Task ID: $TaskId" -ForegroundColor Yellow
    exit 0
}

# Calculate the total duration in seconds across all sessions
$totalSeconds = ($sessions | Measure-Object -Property duration_seconds -Sum).Sum

Write-Host "`nTime sessions for Task #$($sessions[0].task_id) ('$($sessions[0].task_title)'):`n" -ForegroundColor Blue

# Build rows with percentage values
$rows = [System.Collections.Generic.List[PSObject]]::new()

foreach ($session in $sessions) {
    $pct = if ($totalSeconds -gt 0) {
        "{0:P1}" -f ($session.duration_seconds / $totalSeconds)
    } else {
        "0.0%"
    }

    $rows.Add([PSCustomObject]@{
        "Session ID"     = $session.session_id.ToString()
        "Type"           = $session.session_type
        "Started (Local)"= $session.started_at
        "Ended (Local)"  = $session.ended_at
        "Duration (min)" = [math]::Round($session.duration_seconds / 60, 2)
        "% Total"        = $pct
        "Completed"      = if ($session.is_completed -eq 1) { "Yes" } else { "No" }
        "Notes"          = $session.notes
    })
}

$rows.Add([PSCustomObject]@{
    "Session ID"     = ""
    "Type"           = ""
    "Started (Local)"= ""
    "Ended (Local)"  = ""
    "Duration (min)" = ""
    "% Total"        = ""
    "Completed"      = ""
    "Notes"          = ""
})

# Append the summary total row
$rows.Add([PSCustomObject]@{
    "Session ID"     = "---"
    "Type"           = "Total"
    "Started (Local)"= "---"
    "Ended (Local)"  = "---"
    "Duration (min)" = [math]::Round($totalSeconds / 60, 2)
    "% Total"        = "100.0%"
    "Completed"      = "---"
    "Notes"          = ""
})

# Display table
$rows | Format-Table -AutoSize