class TaskItem {
    [int64]$Id
    [string]$Title
    [string]$Notes
    [bool]$IsCompleted
    [Nullable[int64]]$DueDate
    [int64]$CreatedAt
    [Nullable[int64]]$CompletedAt

    TaskItem() {}

    TaskItem([object]$Source) {
        $this.Id          = [int64]$Source.id
        $this.Title       = [string]$Source.title
        $this.Notes       = if ($null -ne $Source.notes) { [string]$Source.notes } else { "" }
        $this.IsCompleted = ([int]$Source.is_completed -eq 1)
        
        if ($null -ne $Source.due_date -and -not [string]::IsNullOrWhiteSpace($Source.due_date)) {
            $this.DueDate = [int64]$Source.due_date
        }
        if ($null -ne $Source.created_at) {
            $this.CreatedAt = [int64]$Source.created_at
        }
        if ($null -ne $Source.completed_at -and -not [string]::IsNullOrWhiteSpace($Source.completed_at)) {
            $this.CompletedAt = [int64]$Source.completed_at
        }
    }
}

function New-TaskItem {
    [CmdletBinding()]
    [OutputType([TaskItem])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Notes,

        [Parameter(Mandatory = $false)]
        [datetime]$DueDate,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $epochDueDate = if ($PSBoundParameters.ContainsKey('DueDate')) {
        [DateTimeOffset]::new($DueDate).ToUnixTimeSeconds()
    } else {
        $null
    }

    $insertQuery = @"
INSERT INTO tasks (title, notes, due_date)
VALUES (@Title, @Notes, @DueDate);
"@
    $parameters = @{
        Title   = $Title
        Notes   = if ([string]::IsNullOrWhiteSpace($Notes)) { $null } else { $Notes }
        DueDate = $epochDueDate
    }

    $inserted = Invoke-SqliteWrapper -Query $insertQuery -Parameters $parameters -DatabasePath $DatabasePath
    if (-not $inserted) {
        return $null
    }

    $rowIdQuery = "SELECT last_insert_rowid() AS id;"
    $rowIdResult = Invoke-SqliteWrapper -Query $rowIdQuery -DatabasePath $DatabasePath -AsJson
    if (-not $rowIdResult -or $rowIdResult.Count -eq 0) {
        return $null
    }
    $newId = [int64]$rowIdResult[0].id

    $existing = Get-TaskItem -Id $newId -DatabasePath $DatabasePath
    return ($existing | Select-Object -First 1)
}

function Get-TaskItem {
    [CmdletBinding(DefaultParameterSetName = "All")]
    [OutputType([TaskItem[]])]
    param (
        [Parameter(ParameterSetName = "ById", Mandatory = $true, Position = 0)]
        [int64]$Id,

        [Parameter(ParameterSetName = "Filter", Mandatory = $false)]
        [ValidateSet("All", "Pending", "Completed")]
        [string]$Status = "All",

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    if ($PSCmdlet.ParameterSetName -eq "ById") {
        $query = "SELECT id, title, notes, is_completed, due_date, created_at, completed_at FROM tasks WHERE id = $Id;"
    } else {
        $whereClause = switch ($Status) {
            "Pending"   { "WHERE is_completed = 0" }
            "Completed" { "WHERE is_completed = 1" }
            Default     { "" }
        }
        $query = "SELECT id, title, notes, is_completed, due_date, created_at, completed_at FROM tasks $whereClause ORDER BY created_at DESC;"
    }

    $rawResults = Invoke-SqliteWrapper -Query $query -DatabasePath $DatabasePath -AsJson
    $items = [System.Collections.Generic.List[TaskItem]]::new()

    foreach ($item in $rawResults) {
        $items.Add([TaskItem]::new($item))
    }

    $items.ToArray()
}

function Complete-TaskItem {
    [CmdletBinding()]
    [OutputType([TaskItem])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int64]$Id,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $completeQuery = "UPDATE tasks SET is_completed = 1, completed_at = CAST(strftime('%s', 'now') AS INTEGER) WHERE id = @Id;"
    $success = Invoke-SqliteWrapper -Query $completeQuery -Parameters @{ Id = $Id } -DatabasePath $DatabasePath

    if ($success) {
        $existing = Get-TaskItem -Id $Id -DatabasePath $DatabasePath
        return ($existing | Select-Object -First 1)
    }
    return $null
}

<#
.SYNOPSIS
    Marks a completed task as pending/reopened.
#>
function Undo-TaskItemCompletion {
    [CmdletBinding()]
    [OutputType([TaskItem])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int64]$Id,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    # Reset completion status and clear completion timestamp
    $reopenQuery = "UPDATE tasks SET is_completed = 0, completed_at = NULL WHERE id = @Id;"
    $success = Invoke-SqliteWrapper -Query $reopenQuery -Parameters @{ Id = $Id } -DatabasePath $DatabasePath

    if ($success) {
        $existing = Get-TaskItem -Id $Id -DatabasePath $DatabasePath
        return ($existing | Select-Object -First 1)
    }
    return $null
}

function Set-TaskItem {
    [CmdletBinding()]
    [OutputType([TaskItem])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int64]$Id,

        [Parameter(Mandatory = $false)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Notes,

        [Parameter(Mandatory = $false)]
        [datetime]$DueDate,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $setClauses = @()
    $params = @{ Id = $Id }

    if ($PSBoundParameters.ContainsKey('Title')) {
        $setClauses += "title = @Title"
        $params['Title'] = $Title
    }

    if ($PSBoundParameters.ContainsKey('Notes')) {
        $setClauses += "notes = @Notes"
        $params['Notes'] = if ([string]::IsNullOrWhiteSpace($Notes)) { $null } else { $Notes }
    }

    if ($PSBoundParameters.ContainsKey('DueDate')) {
        $epoch = [DateTimeOffset]::new($DueDate).ToUnixTimeSeconds()
        $setClauses += "due_date = @DueDate"
        $params['DueDate'] = $epoch
    }

    if ($setClauses.Count -eq 0) {
        Show-WarningMessage "No properties provided to update."
        $existing = Get-TaskItem -Id $Id -DatabasePath $DatabasePath
        return ($existing | Select-Object -First 1)
    }

    $updateString = $setClauses -join ", "
    $updateQuery = "UPDATE tasks SET $updateString WHERE id = @Id;"

    $updated = Invoke-SqliteWrapper -Query $updateQuery -Parameters $params -DatabasePath $DatabasePath
    if (-not $updated) {
        return $null
    }

    $existing = Get-TaskItem -Id $Id -DatabasePath $DatabasePath
    return ($existing | Select-Object -First 1)
}

function Remove-TaskItem {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int64]$Id,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    # Delete associated time_sessions, pivot records, and the task within a single transaction
    $deleteQuery = @"
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;
DELETE FROM time_sessions 
WHERE id IN (SELECT time_session_id FROM task_time_sessions WHERE task_id = $Id);

DELETE FROM task_time_sessions 
WHERE task_id = $Id;

DELETE FROM tasks 
WHERE id = $Id;
COMMIT;
"@
    $result = Invoke-SqliteWrapper -Query $deleteQuery -DatabasePath $DatabasePath
    [bool]$result
}

function Get-TaskSessionItems {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int64]$TaskId,

        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = (Get-SqliteDatabasePath)
    )

    $query = @"
SELECT 
    t.id AS task_id,
    t.title AS task_title,
    s.id AS session_id,
    s.type AS session_type,
    datetime(s.started_at, 'unixepoch', 'localtime') AS started_at,
    CASE 
        WHEN s.ended_at IS NOT NULL THEN datetime(s.ended_at, 'unixepoch', 'localtime')
        ELSE 'ACTIVE' 
    END AS ended_at,
    COALESCE(s.ended_at - s.started_at, CAST(strftime('%s', 'now') AS INTEGER) - s.started_at) AS duration_seconds,
    s.is_completed,
    COALESCE(s.notes, '') AS notes
FROM tasks t
INNER JOIN task_time_sessions tts ON t.id = tts.task_id
INNER JOIN time_sessions s ON tts.time_session_id = s.id
WHERE t.id = $TaskId
ORDER BY s.started_at DESC;
"@

    $result = Invoke-SqliteWrapper -Query $query -DatabasePath $DatabasePath -AsJson
    @($result)
}

Export-ModuleMember -Function `
    Get-TaskSessionItems, `
    New-TaskItem, `
    Get-TaskItem, `
    Undo-TaskItemCompletion, `
    Complete-TaskItem, `
    Set-TaskItem, `
    Remove-TaskItem