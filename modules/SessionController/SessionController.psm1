# Strongly typed DTO for TimeSession items
class TimeSessionItem {
    [int64]$Id
    [string]$Type
    [int64]$StartedAt
    [Nullable[int64]]$EndedAt
    [int64]$DurationSeconds
    [bool]$IsCompleted
    [string]$Notes

    TimeSessionItem() {}

    TimeSessionItem([object]$Source) {
        $this.Id              = [int64]$Source.id
        $this.Type            = [string]$Source.type
        $this.StartedAt       = [int64]$Source.started_at
        if ($null -ne $Source.ended_at -and -not [string]::IsNullOrWhiteSpace($Source.ended_at) -and $Source.ended_at -ne "ACTIVE") {
            $this.EndedAt = [int64]$Source.ended_at
        }
        $this.DurationSeconds = [int64]$Source.duration_seconds
        $this.IsCompleted     = ([int]$Source.is_completed -eq 1)
        $this.Notes           = if ($null -ne $Source.notes) { [string]$Source.notes } else { "" }
    }
}

class TaskSessionLink {
    [int64]$TaskId
    [int64]$SessionId
    [string]$TaskTitle

    TaskSessionLink() {}

    TaskSessionLink([object]$Source) {
        $this.TaskId      = [int64]$Source.task_id
        $this.SessionId   = [int64]$Source.time_session_id
        $this.TaskTitle   = [string]$Source.task_title
    }
}

function Get-TimeSessionItem {
    [CmdletBinding(DefaultParameterSetName = "Recent")]
    [OutputType([TimeSessionItem])]
    param (
        [Parameter(ParameterSetName = "ById", Mandatory = $true, Position = 0)]
        [long]$Id,

        [Parameter(ParameterSetName = "Recent", Mandatory = $false)]
        [int]$Limit = 20,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    if ($PSCmdlet.ParameterSetName -eq "ById") {
        $query = @"
SELECT 
    id,
    type,
    started_at,
    ended_at,
    COALESCE(ended_at - started_at, CAST(strftime('%s', 'now') AS INTEGER) - started_at) AS duration_seconds,
    is_completed,
    COALESCE(notes, '') AS notes
FROM time_sessions 
WHERE id = $Id;
"@
        $raw = @(Invoke-SqliteWrapper -Query $query -DatabasePath $DatabasePath -AsJson)
        if ($raw -and $raw.Count -gt 0) {
            $first = $raw[0]
            if ($null -ne $first) {
                return [TimeSessionItem]::new($first)
            }
        }
        return $null
    } else {
        $query = @"
SELECT 
    id,
    type,
    datetime(started_at, 'unixepoch', 'localtime') AS started_at,
    CASE 
        WHEN ended_at IS NOT NULL THEN datetime(ended_at, 'unixepoch', 'localtime')
        ELSE 'ACTIVE' 
    END AS ended_at,
    COALESCE(ended_at - started_at, CAST(strftime('%s', 'now') AS INTEGER) - started_at) AS duration_seconds,
    is_completed,
    COALESCE(notes, '') AS notes
FROM time_sessions
ORDER BY id DESC
LIMIT $Limit;
"@
        $result = Invoke-SqliteWrapper -Query $query -DatabasePath $DatabasePath -AsJson
        return @($result)
    }
}

function New-TimeSessionItem {
    [CmdletBinding()]
    [OutputType([TimeSessionItem])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("pomodoro_work", "short_break", "long_break", "free_track")]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$StartedAt,

        [Parameter(Mandatory = $false)]
        [Nullable[long]]$EndedAt = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet(0, 1)]
        [int]$IsCompleted = 1,

        [Parameter(Mandatory = $false)]
        [string]$Notes = $null,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    if ($null -ne $EndedAt -and $EndedAt -lt $StartedAt) {
        throw "EndedAt timestamp ($EndedAt) cannot be earlier than StartedAt ($StartedAt)."
    }

    $insertQuery = @"
INSERT INTO time_sessions (type, started_at, ended_at, is_completed, notes)
VALUES (@Type, @StartedAt, @EndedAt, @IsCompleted, @Notes);
"@
    $parameters = @{
        Type        = $Type
        StartedAt   = $StartedAt
        EndedAt     = if ($null -ne $EndedAt) { [long]$EndedAt } else { $null }
        IsCompleted = $IsCompleted
        Notes       = if ([string]::IsNullOrWhiteSpace($Notes)) { $null } else { $Notes }
    }

    $inserted = Invoke-SqliteWrapper -Query $insertQuery -Parameters $parameters -DatabasePath $DatabasePath
    if (-not $inserted) {
        return $null
    }

    Write-Host $inserted

    $rowIdQuery = "SELECT MAX(id) AS id FROM time_sessions;"
    $rowIdResult = Invoke-SqliteWrapper -Query $rowIdQuery -DatabasePath $DatabasePath -AsJson
    if (-not $rowIdResult -or $rowIdResult.Count -eq 0) {
        return $null
    }
    
    # Safe property extraction compatible PS5 & PS7
    $targetObj = $rowIdResult | Select-Object -First 1
    $newId = [int64]$targetObj.id

    Write-Host $newId

    $existing = Get-TimeSessionItem -Id $newId -DatabasePath $DatabasePath

    Write-Host $existing
    return ($existing | Select-Object -First 1)
}

function Add-TaskSessionLink {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [long]$TaskId,

        [Parameter(Mandatory = $true)]
        [long]$SessionId,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $sqlQuery = @"
PRAGMA foreign_keys = ON;
INSERT OR REPLACE INTO task_time_sessions (task_id, time_session_id)
VALUES ($TaskId, $SessionId);
"@

    $success = Invoke-SqliteWrapper -Query $sqlQuery -DatabasePath $DatabasePath
    [bool]$success
}

function Remove-TimeSessionItem {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [long]$Id,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $sqlQuery = @"
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;
DELETE FROM task_time_sessions WHERE time_session_id = $Id;
DELETE FROM time_sessions WHERE id = $Id;
COMMIT;
"@
    $result = Invoke-SqliteWrapper -Query $sqlQuery -DatabasePath $DatabasePath
    [bool]$result
}

function Get-TaskSessionLinkBySessionId {
    [CmdletBinding()]
    [OutputType([TaskSessionLink[]])]
    param (
        [Parameter(Mandatory = $true)]
        [long]$SessionId,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $query = @"
SELECT 
    tts.task_id,
    tts.time_session_id,
    t.title AS task_title
FROM task_time_sessions tts
INNER JOIN tasks t ON tts.task_id = t.id
WHERE tts.time_session_id = $SessionId;
"@

    $raw = Invoke-SqliteWrapper -Query $query -DatabasePath $DatabasePath -AsJson
    $links = [System.Collections.Generic.List[TaskSessionLink]]::new()
    foreach ($item in $raw) {
        $links.Add([TaskSessionLink]::new($item))
    }
    $links.ToArray()
}

function Remove-TaskSessionLinkBySessionId {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [long]$SessionId,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $sqlQuery = @"
PRAGMA foreign_keys = ON;
DELETE FROM task_time_sessions WHERE time_session_id = $SessionId;
"@
    $result = Invoke-SqliteWrapper -Query $sqlQuery -DatabasePath $DatabasePath
    [bool]$result
}


function Set-TimeSessionItem { 
    [CmdletBinding()] 
    [OutputType([TimeSessionItem])] 
    param ( 
        [Parameter(Mandatory = $true, Position = 0)] 
        [long]$Id, 

        [Parameter(Mandatory = $false)] 
        [ValidateSet("pomodoro_work", "short_break", "long_break", "free_track")] 
        [string]$Type, 

        [Parameter(Mandatory = $false)] 
        [Nullable[long]]$StartedAt, 

        [Parameter(Mandatory = $false)] 
        [Nullable[long]]$EndedAt, 

        [Parameter(Mandatory = $false)] 
        [ValidateSet(0, 1)] 
        [Nullable[int]]$IsCompleted, 

        [Parameter(Mandatory = $false)] 
        [string]$Notes, 

        [Parameter(Mandatory = $false)] 
        [string]$DatabasePath = (Get-SqliteDatabasePath) 
    ) 

    if ($PSBoundParameters.ContainsKey('StartedAt') -and $PSBoundParameters.ContainsKey('EndedAt')) { 
        if ($null -ne $StartedAt -and $null -ne $EndedAt -and $EndedAt -lt $StartedAt) { 
            throw "EndedAt timestamp ($EndedAt) cannot be earlier than StartedAt ($StartedAt)." 
        } 
    } 

    $setClauses = @() 
    $params = @{ Id = $Id } 

    if ($PSBoundParameters.ContainsKey('Type')) { 
        $setClauses += "type = @Type" 
        $params['Type'] = $Type 
    } 

    if ($PSBoundParameters.ContainsKey('StartedAt') -and $null -ne $StartedAt) { 
        $setClauses += "started_at = @StartedAt" 
        $params['StartedAt'] = $StartedAt 
    } 

    if ($PSBoundParameters.ContainsKey('EndedAt')) { 
        $setClauses += "ended_at = @EndedAt" 
        $params['EndedAt'] = if ($null -ne $EndedAt) { [long]$EndedAt } else { $null } 
    } 

    if ($PSBoundParameters.ContainsKey('IsCompleted') -and $null -ne $IsCompleted) { 
        $setClauses += "is_completed = @IsCompleted" 
        $params['IsCompleted'] = $IsCompleted 
    } 

    if ($PSBoundParameters.ContainsKey('Notes')) { 
        $setClauses += "notes = @Notes" 
        $params['Notes'] = if ([string]::IsNullOrWhiteSpace($Notes)) { $null } else { $Notes } 
    } 

    if ($setClauses.Count -eq 0) { 
        Show-WarningMessage "No session fields provided to update." 
        return (Get-TimeSessionItem -Id $Id -DatabasePath $DatabasePath) 
    } 

    $updateString = $setClauses -join ", " 
    $updateQuery = "UPDATE time_sessions SET $updateString WHERE id = @Id;" 

    $updated = Invoke-SqliteWrapper -Query $updateQuery -Parameters $params -DatabasePath $DatabasePath 
    if (-not $updated) { 
        return $null 
    } 

    Get-TimeSessionItem -Id $Id -DatabasePath $DatabasePath 
} 

Export-ModuleMember -Function `
    New-TimeSessionItem, `
    Get-TimeSessionItem, `
    Set-TimeSessionItem, `
    Add-TaskSessionLink, `
    Remove-TimeSessionItem, `
    Remove-TaskSessionLinkBySessionId, `
    Get-TaskSessionLinkBySessionId