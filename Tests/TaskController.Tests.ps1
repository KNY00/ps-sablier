# Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for TaskController module using Pester.
#>

. (Join-Path $PSScriptRoot "TestHelper.ps1")

Describe "TaskController Database Operations" {
    BeforeAll {
        # Dot-source helper within the test execution scope
        $helperPath = Join-Path $PSScriptRoot "TestHelper.ps1"
        if (-not (Test-Path -LiteralPath $helperPath)) {
            # Fallback path if PSScriptRoot is not set in container scope
            $helperPath = Join-Path $pwd "Tests\TestHelper.ps1"
        }
        . $helperPath

        $script:TestDb = Initialize-TestDatabaseEnvironment
        Import-Module TaskController -Force -ErrorAction Stop
        Import-Module SessionController -Force -ErrorAction Stop
    }

    AfterAll {
        Remove-TestDatabaseEnvironment -DatabasePath $script:TestDb
    }

    Context "New-TaskItem" {
        It "Creates a new task and returns a TaskItem instance" {
            $task = New-TaskItem -Title "Implement Unit Tests" -Notes "Pester coverage" -DatabasePath $script:TestDb

            $task | Should -Not -BeNullOrEmpty
            $task.Id | Should -BeGreaterThan 0
            $task.Title | Should -Be "Implement Unit Tests"
            $task.Notes | Should -Be "Pester coverage"
            $task.IsCompleted | Should -Be $false
            $task.CreatedAt | Should -BeGreaterThan 0
            $task.DueDate | Should -BeNullOrEmpty
        }

        It "Persists DueDate converted to unix timestamp" {
            $targetDue = (Get-Date).AddDays(3)
            $expectedEpoch = [DateTimeOffset]::new($targetDue).ToUnixTimeSeconds()

            $task = New-TaskItem -Title "Task With Deadline" -DueDate $targetDue -DatabasePath $script:TestDb

            $task | Should -Not -BeNullOrEmpty
            $task.DueDate | Should -Be $expectedEpoch
        }
    }

    Context "Get-TaskItem" {
        BeforeAll {
            # Reset table data before testing filters
            Invoke-SqliteWrapper -Query "DELETE FROM tasks;" -DatabasePath $script:TestDb | Out-Null

            $script:pendingTask = New-TaskItem -Title "Task Pending" -DatabasePath $script:TestDb
            $script:completedTask = New-TaskItem -Title "Task Completed" -DatabasePath $script:TestDb
            Complete-TaskItem -Id $script:completedTask.Id -DatabasePath $script:TestDb | Out-Null
        }

        It "Retrieves a specific task using ById parameter set" {
            $task = Get-TaskItem -Id $script:pendingTask.Id -DatabasePath $script:TestDb

            $task | Should -Not -BeNullOrEmpty
            $task.Id | Should -Be $script:pendingTask.Id
            $task.Title | Should -Be "Task Pending"
        }

        It "Filters tasks by Pending status" {
            $pendingList = Get-TaskItem -Status "Pending" -DatabasePath $script:TestDb

            $pendingList.Count | Should -Be 1
            $pendingList[0].Id | Should -Be $script:pendingTask.Id
        }

        It "Filters tasks by Completed status" {
            $completedList = Get-TaskItem -Status "Completed" -DatabasePath $script:TestDb

            $completedList.Count | Should -Be 1
            $completedList[0].Id | Should -Be $script:completedTask.Id
        }

        It "Returns all tasks when Status is All" {
            $allTasks = Get-TaskItem -Status "All" -DatabasePath $script:TestDb

            $allTasks.Count | Should -Be 2
        }
    }

    Context "Complete-TaskItem and Undo-TaskItemCompletion" {
        It "Sets IsCompleted to true and assigns a valid CompletedAt timestamp" {
            $task = New-TaskItem -Title "Task To Finish" -DatabasePath $script:TestDb
            $finished = Complete-TaskItem -Id $task.Id -DatabasePath $script:TestDb

            $finished.IsCompleted | Should -Be $true
            $finished.CompletedAt | Should -Not -BeNullOrEmpty
            $finished.CompletedAt | Should -BeGreaterThan 0
        }

        It "Reopens a completed task and clears CompletedAt" {
            $task = New-TaskItem -Title "Task To Reopen" -DatabasePath $script:TestDb
            Complete-TaskItem -Id $task.Id -DatabasePath $script:TestDb | Out-Null

            $reopened = Undo-TaskItemCompletion -Id $task.Id -DatabasePath $script:TestDb

            $reopened.IsCompleted | Should -Be $false
            $reopened.CompletedAt | Should -BeNullOrEmpty
        }
    }

    Context "Set-TaskItem" {
        It "Updates title, notes, and due date for an existing task" {
            $task = New-TaskItem -Title "Old Title" -Notes "Old Notes" -DatabasePath $script:TestDb
            $newDue = (Get-Date).AddDays(7)
            $expectedEpoch = [DateTimeOffset]::new($newDue).ToUnixTimeSeconds()

            $updated = Set-TaskItem -Id $task.Id -Title "New Title" -Notes "New Notes" -DueDate $newDue -DatabasePath $script:TestDb

            $updated.Id | Should -Be $task.Id
            $updated.Title | Should -Be "New Title"
            $updated.Notes | Should -Be "New Notes"
            $updated.DueDate | Should -Be $expectedEpoch
        }

        It "Returns the unmodified task if no fields are supplied" {
            $task = New-TaskItem -Title "Untouched" -DatabasePath $script:TestDb
            $result = Set-TaskItem -Id $task.Id -DatabasePath $script:TestDb

            $result.Title | Should -Be "Untouched"
        }
    }

    Context "Remove-TaskItem and Get-TaskSessionItems" {
        It "Retrieves associated time sessions for a task via Get-TaskSessionItems" {
            $task = New-TaskItem -Title "Task With Sessions" -DatabasePath $script:TestDb
            $session = New-TimeSessionItem -Type "pomodoro_work" -StartedAt 1700000000 -EndedAt 1700001500 -DatabasePath $script:TestDb
            Add-TaskSessionLink -TaskId $task.Id -SessionId $session.Id -DatabasePath $script:TestDb | Out-Null

            $sessions = Get-TaskSessionItems -TaskId $task.Id -DatabasePath $script:TestDb

            $sessions.Count | Should -Be 1
            $sessions[0].task_id | Should -Be $task.Id
            $sessions[0].session_id | Should -Be $session.Id
            $sessions[0].session_type | Should -Be "pomodoro_work"
        }

        It "Deletes task and cascades deletion to linked sessions and pivot records" {
            $task = New-TaskItem -Title "Task Cascade Delete" -DatabasePath $script:TestDb
            $session = New-TimeSessionItem -Type "short_break" -StartedAt 1700000000 -EndedAt 1700000300 -DatabasePath $script:TestDb
            Add-TaskSessionLink -TaskId $task.Id -SessionId $session.Id -DatabasePath $script:TestDb | Out-Null

            $removed = Remove-TaskItem -Id $task.Id -DatabasePath $script:TestDb
            $removed | Should -Be $true

            # Ensure task, session, and pivot are completely removed
            (Get-TaskItem -Id $task.Id -DatabasePath $script:TestDb) | Should -BeNullOrEmpty
            (Get-TimeSessionItem -Id $session.Id -DatabasePath $script:TestDb) | Should -BeNullOrEmpty
            (Get-TaskSessionLinkBySessionId -SessionId $session.Id -DatabasePath $script:TestDb).Count | Should -Be 0
        }
    }
}