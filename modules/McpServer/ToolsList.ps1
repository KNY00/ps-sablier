<#
.SYNOPSIS
    Centralized tool definitions and dispatch logic for MCP and local agents.
#>

function Get-McpToolsList {
    <#
    .SYNOPSIS
        Returns the official list of MCP tools with their JSON schemas.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param ()

    return @{
        tools = @(
            # --- Session Tools ---
            @{
                name = "get_sessions"
                description = "Retrieves recent time sessions or a specific session by ID."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        id = @{ type = "integer" }
                        limit = @{ type = "integer" }
                    }
                }
            },
            @{
                name = "create_session"
                description = "Creates a new time session."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        type = @{ type = "string"; enum = @("pomodoro_work", "short_break", "long_break", "free_track") }
                        startedAt = @{ type = "integer" }
                        endedAt = @{ type = "integer" }
                        isCompleted = @{ type = "integer"; enum = @(0, 1) }
                        notes = @{ type = "string" }
                    }
                    required = @("type", "startedAt")
                }
            },
            @{
                name = "update_session"
                description = "Updates an existing session properties."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        id = @{ type = "integer" }
                        type = @{ type = "string"; enum = @("pomodoro_work", "short_break", "long_break", "free_track") }
                        startedAt = @{ type = "integer" }
                        endedAt = @{ type = "integer" }
                        isCompleted = @{ type = "integer"; enum = @(0, 1) }
                        notes = @{ type = "string" }
                    }
                    required = @("id")
                }
            },
            @{
                name = "delete_session"
                description = "Deletes a session by ID."
                inputSchema = @{
                    type = "object"
                    properties = @{ id = @{ type = "integer" } }
                    required = @("id")
                }
            },
            # --- Task Tools ---
            @{
                name = "get_tasks"
                description = "Retrieves tasks based on status filter or ID."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        id = @{ type = "integer" }
                        status = @{ type = "string"; enum = @("All", "Pending", "Completed") }
                    }
                }
            },
            @{
                name = "create_task"
                description = "Creates a new task."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        title = @{ type = "string" }
                        notes = @{ type = "string" }
                        dueDate = @{ type = "string"; description = "Date string parseable by .NET (e.g., '2026-12-31')" }
                    }
                    required = @("title")
                }
            },
            @{
                name = "update_task"
                description = "Updates a task details."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        id = @{ type = "integer" }
                        title = @{ type = "string" }
                        notes = @{ type = "string" }
                        dueDate = @{ type = "string" }
                    }
                    required = @("id")
                }
            },
            @{
                name = "complete_task"
                description = "Marks a task as completed."
                inputSchema = @{
                    type = "object"
                    properties = @{ id = @{ type = "integer" } }
                    required = @("id")
                }
            },
            @{
                name = "reopen_task"
                description = "Reopens a completed task, marking it as pending."
                inputSchema = @{
                    type = "object"
                    properties = @{ id = @{ type = "integer" } }
                    required = @("id")
                }
            },
            @{
                name = "delete_task"
                description = "Deletes a task by ID."
                inputSchema = @{
                    type = "object"
                    properties = @{ id = @{ type = "integer" } }
                    required = @("id")
                }
            },
            # --- Linking Tools ---
            @{
                name = "link_task_session"
                description = "Links a session to a task."
                inputSchema = @{
                    type = "object"
                    properties = @{
                        taskId = @{ type = "integer" }
                        sessionId = @{ type = "integer" }
                    }
                    required = @("taskId", "sessionId")
                }
            },
            @{
                name = "unlink_task_session"
                description = "Unlinks a session from its associated task."
                inputSchema = @{
                    type = "object"
                    properties = @{ sessionId = @{ type = "integer" } }
                    required = @("sessionId")
                }
            },
            @{
                name = "get_task_sessions"
                description = "Retrieves all time sessions linked to a specific task."
                inputSchema = @{
                    type = "object"
                    properties = @{ taskId = @{ type = "integer" } }
                    required = @("taskId")
                }
            }
        )
    }
}

function Invoke-McpToolCall {
    <#
    .SYNOPSIS
        Executes a tool call by name with the given arguments and returns a serialized string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [object]$Arguments = @{}
    )

    $requestArgs = $Arguments
    $resultContent = ""

    switch ($Name) {
        # Sessions
        "get_sessions" {
            if ($null -ne $requestArgs.id) {
                $resultContent = Get-TimeSessionItem -Id ([int64]$requestArgs.id) | ConvertTo-Json -Depth 3 -Compress
            } else {
                $limit = if ($null -ne $requestArgs.limit) { [int]$requestArgs.limit } else { 20 }
                $resultContent = Get-TimeSessionItem -Limit $limit | ConvertTo-Json -Depth 3 -Compress
            }
        }
        "create_session" {
            $params = @{
                Type      = [string]$requestArgs.type
                StartedAt = [int64]$requestArgs.startedAt
            }
            if ($null -ne $requestArgs.endedAt)     { $params["EndedAt"]     = [int64]$requestArgs.endedAt }
            if ($null -ne $requestArgs.isCompleted) { $params["IsCompleted"] = [int]$requestArgs.isCompleted }
            if ($null -ne $requestArgs.notes)       { $params["Notes"]       = [string]$requestArgs.notes }
            
            $created = New-TimeSessionItem @params
            $resultContent = $created | ConvertTo-Json -Depth 3 -Compress
        }
        "update_session" {
            $params = @{ Id = [int64]$requestArgs.id }
            if ($null -ne $requestArgs.type)        { $params["Type"]        = [string]$requestArgs.type }
            if ($null -ne $requestArgs.startedAt)   { $params["StartedAt"]   = [int64]$requestArgs.startedAt }
            if ($null -ne $requestArgs.endedAt)     { $params["EndedAt"]     = [int64]$requestArgs.endedAt }
            if ($null -ne $requestArgs.isCompleted) { $params["IsCompleted"] = [int]$requestArgs.isCompleted }
            if ($null -ne $requestArgs.notes)       { $params["Notes"]       = [string]$requestArgs.notes }
            
            $updated = Set-TimeSessionItem @params
            $resultContent = $updated | ConvertTo-Json -Depth 3 -Compress
        }
        "delete_session" {
            $removed = Remove-TimeSessionItem -Id ([int64]$requestArgs.id)
            $resultContent = "Session $($requestArgs.id) removed: $removed"
        }
        
        # Tasks
        "get_tasks" {
            if ($null -ne $requestArgs.id) {
                $resultContent = Get-TaskItem -Id ([int64]$requestArgs.id) | ConvertTo-Json -Depth 3 -Compress
            } else {
                $status = if ($null -ne $requestArgs.status) { [string]$requestArgs.status } else { "All" }
                $resultContent = Get-TaskItem -Status $status | ConvertTo-Json -Depth 3 -Compress
            }
        }
        "create_task" {
            $params = @{ Title = [string]$requestArgs.title }
            if ($null -ne $requestArgs.notes)   { $params["Notes"]   = [string]$requestArgs.notes }
            if ($null -ne $requestArgs.dueDate) { $params["DueDate"] = [datetime]$requestArgs.dueDate }
            
            $created = New-TaskItem @params
            $resultContent = $created | ConvertTo-Json -Depth 3 -Compress
        }
        "update_task" {
            $params = @{ Id = [int64]$requestArgs.id }
            if ($null -ne $requestArgs.title)   { $params["Title"]   = [string]$requestArgs.title }
            if ($null -ne $requestArgs.notes)   { $params["Notes"]   = [string]$requestArgs.notes }
            if ($null -ne $requestArgs.dueDate) { $params["DueDate"] = [datetime]$requestArgs.dueDate }
            
            $updated = Set-TaskItem @params
            $resultContent = $updated | ConvertTo-Json -Depth 3 -Compress
        }
        "complete_task" {
            $updated = Complete-TaskItem -Id ([int64]$requestArgs.id)
            $resultContent = $updated | ConvertTo-Json -Depth 3 -Compress
        }
        "reopen_task" {
            $updated = Undo-TaskItemCompletion -Id ([int64]$requestArgs.id)
            $resultContent = $updated | ConvertTo-Json -Depth 3 -Compress
        }
        "delete_task" {
            $removed = Remove-TaskItem -Id ([int64]$requestArgs.id)
            $resultContent = "Task $($requestArgs.id) removed: $removed"
        }
        
        # Linking
        "link_task_session" {
            $linked = Add-TaskSessionLink -TaskId ([int64]$requestArgs.taskId) -SessionId ([int64]$requestArgs.sessionId)
            $resultContent = "Task $($requestArgs.taskId) linked to Session $($requestArgs.sessionId): $linked"
        }
        "unlink_task_session" {
            $removed = Remove-TaskSessionLinkBySessionId -SessionId ([int64]$requestArgs.sessionId)
            $resultContent = "Session $($requestArgs.sessionId) unlinked: $removed"
        }
        "get_task_sessions" {
            $sessions = Get-TaskSessionItems -TaskId ([int64]$requestArgs.taskId)
            if ($null -eq $sessions) { $sessions = @() }
            $resultContent = $sessions | ConvertTo-Json -Depth 3 -Compress
        }
        default {
            throw "Unknown tool: $Name"
        }
    }

    if ($null -eq $resultContent) {
        $resultContent = "{}"
    }

    return $resultContent
}