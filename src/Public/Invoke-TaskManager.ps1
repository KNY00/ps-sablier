<#
.SYNOPSIS
    Interactive task management menu.

.DESCRIPTION
    Provides terminal navigation to list, create, complete, update, delete,
    and search tasks, as well as inspect logged time sessions associated with specific tasks.

.EXAMPLE
    .\Invoke-TaskManager.ps1
#>

[CmdletBinding()]
param ()

Import-Module CheckDependencies -ErrorAction Stop
Import-Module TaskController -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop
Import-Module TimeUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

Test-ProjectPrerequisite

function Invoke-TaskUpdateWorkflow {
    $idInput = Read-Host "Enter Task ID to update"
    $taskId = 0L
    if (-not [int64]::TryParse($idInput, [ref]$taskId)) {
        Show-ErrorMessage "Invalid Task ID."
        return
    }

    $task = Get-TaskItem -Id $taskId | Select-Object -First 1
    if (-not $task) {
        Show-InfoMessage "Task #$taskId was not found."
        return
    }

    Write-Host "`nEditing Task #$($task.Id) - '$($task.Title)'" -ForegroundColor Cyan

    $updateParams = @{
        Id = $taskId
    }

    # 1. Update Title
    $changeTitle = Show-Menu -Title "Update task title?" -Options @("Keep Current ($($task.Title))", "Change Title")
    if ($changeTitle -eq "Change Title") {
        $newTitle = Read-Host "Enter new title"
        if (-not [string]::IsNullOrWhiteSpace($newTitle)) {
            $updateParams["Title"] = $newTitle
        } else {
            Show-InfoMessage "Title cannot be empty. Title remains unchanged."
        }
    }

    # 2. Update Notes
    $changeNotes = Show-Menu -Title "Update task notes?" -Options @("Keep Current Notes", "Change Notes")
    if ($changeNotes -eq "Change Notes") {
        $newNotes = Read-Host "Enter notes (leave empty to clear)"
        $updateParams["Notes"] = $newNotes
    }

    # 3. Update Due Date
    $currentDueStr = if ($task.DueDate) {
        [DateTimeOffset]::FromUnixTimeSeconds($task.DueDate).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
    } else {
        "None"
    }

    $changeDueDate = Show-Menu -Title "Update due date? (Current: $currentDueStr)" -Options @("Keep Current Due Date", "Set New Due Date")
    if ($changeDueDate -eq "Set New Due Date") {
        Write-Host "Select new due date and time:" -ForegroundColor Blue
        $pickedDate = Read-DateTimeInteractive
        $updateParams["DueDate"] = $pickedDate.DateTime
    }

    # Apply updates via TaskController
    $updated = Set-TaskItem @updateParams
    if ($updated) {
        Show-SuccessMessage "Task #$taskId updated successfully."
    } else {
        Show-ErrorMessage "Failed to update Task #$taskId."
    }
}

function Invoke-TaskDeleteWorkflow {
    $idInput = Read-Host "Enter Task ID to delete"
    $taskId = 0L
    if (-not [int64]::TryParse($idInput, [ref]$taskId)) {
        Show-ErrorMessage "Invalid Task ID."
        return
    }

    $task = Get-TaskItem -Id $taskId | Select-Object -First 1
    if (-not $task) {
        Show-InfoMessage "Task #$taskId was not found."
        return
    }

    # Inspect linked sessions to warn the user
    $sessions = Get-TaskSessionItems -TaskId $taskId
    $sessionCount = if ($sessions) { $sessions.Count } else { 0 }

    if ($sessionCount -gt 0) {
        Show-WarningMessage "Task #$taskId ('$($task.Title)') has $sessionCount associated session(s). Deleting this task will also permanently delete all related sessions."
    }

    $confirmed = Confirm-Action -Message "Are you sure you want to delete Task #$taskId ('$($task.Title)')?"
    if (-not $confirmed) {
        Show-InfoMessage "Task deletion cancelled."
        return
    }

    $deleted = Remove-TaskItem -Id $taskId
    if ($deleted) {
        Show-SuccessMessage "Task #$taskId and its associated session(s) were successfully deleted."
    } else {
        Show-ErrorMessage "Failed to delete Task #$taskId."
    }
}

function Invoke-TaskCompletionWorkflow {
    $idInput = Read-Host "Enter Task ID"
    $taskId = 0L
    if (-not [int64]::TryParse($idInput, [ref]$taskId)) {
        Show-ErrorMessage "Invalid Task ID."
        return
    }

    $task = Get-TaskItem -Id $taskId | Select-Object -First 1
    if (-not $task) {
        Show-InfoMessage "Task #$taskId was not found."
        return
    }

    # Determine current status
    $currentStatusLabel = if ($task.IsCompleted) { "Completed" } else { "Pending" }
    Write-Host "`nTask #$($task.Id) ('$($task.Title)') is currently $currentStatusLabel." -ForegroundColor Cyan

    # Ask the user whether to Complete, Reopen, or Cancel
    $actionOptions = @("Complete", "Reopen", "Cancel")
    $chosenAction = Show-Menu -Title "Choose action to perform on Task #$taskId :" -Options $actionOptions

    switch ($chosenAction) {
        "Complete" {
            if ($task.IsCompleted) {
                Show-InfoMessage "Task #$taskId is already marked as completed."
                return
            }
            $updated = Complete-TaskItem -Id $taskId
            if ($updated) {
                Show-SuccessMessage "Task #$taskId marked as completed."
            } else {
                Show-ErrorMessage "Failed to complete Task #$taskId."
            }
        }
        "Reopen" {
            if (-not $task.IsCompleted) {
                Show-InfoMessage "Task #$taskId is already open (pending)."
                return
            }
            $updated = Undo-TaskItemCompletion -Id $taskId
            if ($updated) {
                Show-SuccessMessage "Task #$taskId reopened (status reset to pending)."
            } else {
                Show-ErrorMessage "Failed to reopen Task #$taskId."
            }
        }
        "Cancel" {
            Write-Host "Action cancelled." -ForegroundColor Yellow
        }
    }
}

function Show-TaskMenu {
    $menuOptions = @(
        "List Tasks",
        "Add Task",
        "Update Task",
        "Complete / Reopen Task",
        "Delete Task",
        "Search Tasks",
        "View Task Sessions",
        "Exit"
    )

    while ($true) {
        Clear-Host
        $Choice = Show-Menu -Title "=== Task Manager ===" -Options $menuOptions

        # Exit and return to caller (Start.ps1) if Escape was pressed or Exit selected
        if ([string]::IsNullOrWhiteSpace($Choice) -or $Choice -eq "Exit") {
            return
        }

        switch ($Choice) {
            "List Tasks" {
                $statusChoice = Show-Menu -Title "Filter by status:" -Options @("Pending", "Completed", "All")
                $tasks = Get-TaskItem -Status $statusChoice

                if ($tasks -and $tasks.Count -gt 0) {
                    $tasks | Format-Table -Property Id, Title, Notes, `
                        @{ Name = "Completed"; Expression = { if ($_.IsCompleted) { "Yes" } else { "No" } } }, `
                        @{ Name = "DueDate"; Expression = { if ($_.DueDate) { [DateTimeOffset]::FromUnixTimeSeconds($_.DueDate).ToLocalTime().ToString("yyyy-MM-dd HH:mm") } else { "-" } } } `
                        -AutoSize
                } else {
                    Write-Host "No tasks found." -ForegroundColor Yellow
                }
                Pause
            }

            "Add Task" {
                $title = Read-Host "Task title"
                if ([string]::IsNullOrWhiteSpace($title)) {
                    Show-InfoMessage "Title cannot be empty."
                } else {
                    $notes = Read-Host "Notes (optional)"
                    New-TaskItem -Title $title -Notes $notes | Out-Null
                    Show-SuccessMessage "Task created successfully."
                }
                Pause
            }

            "Update Task" {
                Invoke-TaskUpdateWorkflow
                Pause
            }

            "Complete / Reopen Task" {
                Invoke-TaskCompletionWorkflow
                Pause
            }

            "Delete Task" {
                Invoke-TaskDeleteWorkflow
                Pause
            }

            "Search Tasks" {
                & "$PSScriptRoot\..\Private\Helpers\Find-Task.ps1"
            }

            "View Task Sessions" {
                $idInput = Read-Host "Enter Task ID"
                $taskId = 0L
                if ([int64]::TryParse($idInput, [ref]$taskId)) {
                    & "$PSScriptRoot\..\Private\Helpers\Get-TaskSessions.ps1" -TaskId $taskId
                } else {
                    Show-ErrorMessage "Invalid Task ID."
                }
                Pause
            }

            "Exit" {
                return
            }
        }
    }
}

Show-TaskMenu