# Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for SessionController module using Pester.
#>

. (Join-Path $PSScriptRoot "TestHelper.ps1")

Describe "SessionController Database Operations" {
    BeforeAll {
        # Dot-source helper within the test execution scope
        $helperPath = Join-Path $PSScriptRoot "TestHelper.ps1"
        if (-not (Test-Path -LiteralPath $helperPath)) {
            # Fallback path if PSScriptRoot is not set in container scope
            $helperPath = Join-Path $pwd "Tests\TestHelper.ps1"
        }
        . $helperPath

        $script:TestDb = Initialize-TestDatabaseEnvironment
        Import-Module SessionController -Force -ErrorAction Stop
        Import-Module TaskController -Force -ErrorAction Stop
    }

    AfterAll {
        Remove-TestDatabaseEnvironment -DatabasePath $script:TestDb
    }

    Context "New-TimeSessionItem" {
        It "Throws an error if EndedAt is earlier than StartedAt" {
            {
                New-TimeSessionItem -Type "pomodoro_work" -StartedAt 1700002000 -EndedAt 1700001000 -DatabasePath $script:TestDb
            } | Should -Throw
        }

        It "Creates a completed session with correct timestamps and notes" {
            $start = 1700000000
            $end = 1700001500
            $session = New-TimeSessionItem -Type "pomodoro_work" -StartedAt $start -EndedAt $end -IsCompleted 1 -Notes "Sprint task focus" -DatabasePath $script:TestDb

            $session | Should -Not -BeNullOrEmpty
            $session.Id | Should -BeGreaterThan 0
            $session.Type | Should -Be "pomodoro_work"
            $session.StartedAt | Should -Be $start
            $session.EndedAt | Should -Be $end
            $session.DurationSeconds | Should -Be ($end - $start)
            $session.IsCompleted | Should -Be $true
            $session.Notes | Should -Be "Sprint task focus"
        }

        # It "Creates an active tracking session when EndedAt is omitted" {
        #     $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        #     $activeSession = New-TimeSessionItem -Type "free_track" -StartedAt $now -DatabasePath $script:TestDb

        #     $activeSession | Should -Not -BeNullOrEmpty
        #     $activeSession.EndedAt | Should -BeNullOrEmpty
        #     $activeSession.DurationSeconds | Should -BeGreaterThanOrEqual 0
        # }
    }

    Context "Get-TimeSessionItem" {
        It "Retrieves an existing session by ID" {
            $session = New-TimeSessionItem -Type "short_break" -StartedAt 1700005000 -EndedAt 1700005300 -DatabasePath $script:TestDb
            $found = Get-TimeSessionItem -Id $session.Id -DatabasePath $script:TestDb

            $found | Should -Not -BeNullOrEmpty
            $found.Id | Should -Be $session.Id
            $found.Type | Should -Be "short_break"
        }

        It "Retrieves recent sessions respecting the Limit parameter" {
            1..6 | ForEach-Object {
                New-TimeSessionItem -Type "long_break" -StartedAt (1700010000 + $_ * 100) -EndedAt (1700010000 + $_ * 100 + 50) -DatabasePath $script:TestDb | Out-Null
            }

            $recentSessions = Get-TimeSessionItem -Limit 4 -DatabasePath $script:TestDb
            $recentSessions.Count | Should -Be 4
        }
    }

    Context "Set-TimeSessionItem" {
        It "Throws when modifying timestamps so EndedAt is earlier than StartedAt" {
            $session = New-TimeSessionItem -Type "pomodoro_work" -StartedAt 1700000000 -EndedAt 1700001500 -DatabasePath $script:TestDb

            {
                Set-TimeSessionItem -Id $session.Id -StartedAt 1700003000 -EndedAt 1700002000 -DatabasePath $script:TestDb
            } | Should -Throw
        }

        It "Updates session properties properly" {
            $session = New-TimeSessionItem -Type "pomodoro_work" -StartedAt 1700000000 -DatabasePath $script:TestDb
            $newEnd = 1700001200

            $updated = Set-TimeSessionItem -Id $session.Id -Type "short_break" -EndedAt $newEnd -IsCompleted 1 -Notes "Updated notes" -DatabasePath $script:TestDb

            $updated.Id | Should -Be $session.Id
            $updated.Type | Should -Be "short_break"
            $updated.EndedAt | Should -Be $newEnd
            $updated.IsCompleted | Should -Be $true
            $updated.Notes | Should -Be "Updated notes"
        }
    }

    Context "Task and Session Association" {
        BeforeAll {
            $script:taskObj = New-TaskItem -Title "Association Target Task" -DatabasePath $script:TestDb
            $script:sessionObj = New-TimeSessionItem -Type "pomodoro_work" -StartedAt 1700000000 -EndedAt 1700001500 -DatabasePath $script:TestDb
        }

        It "Associates a session to a task using Add-TaskSessionLink" {
            $success = Add-TaskSessionLink -TaskId $script:taskObj.Id -SessionId $script:sessionObj.Id -DatabasePath $script:TestDb
            $success | Should -Be $true
        }

        It "Reads link info via Get-TaskSessionLinkBySessionId" {
            $links = Get-TaskSessionLinkBySessionId -SessionId $script:sessionObj.Id -DatabasePath $script:TestDb

            $links.Count | Should -Be 1
            $links[0].TaskId | Should -Be $script:taskObj.Id
            $links[0].SessionId | Should -Be $script:sessionObj.Id
            $links[0].TaskTitle | Should -Be "Association Target Task"
        }

        It "Removes task-session association using Remove-TaskSessionLinkBySessionId" {
            $removed = Remove-TaskSessionLinkBySessionId -SessionId $script:sessionObj.Id -DatabasePath $script:TestDb
            $removed | Should -Be $true

            $remaining = Get-TaskSessionLinkBySessionId -SessionId $script:sessionObj.Id -DatabasePath $script:TestDb
            $remaining.Count | Should -Be 0
        }
    }

    Context "Remove-TimeSessionItem" {
        It "Deletes a session and its associated link from pivot table" {
            $task = New-TaskItem -Title "Session Delete Target" -DatabasePath $script:TestDb
            $session = New-TimeSessionItem -Type "pomodoro_work" -StartedAt 1700000000 -EndedAt 1700001500 -DatabasePath $script:TestDb
            Add-TaskSessionLink -TaskId $task.Id -SessionId $session.Id -DatabasePath $script:TestDb | Out-Null

            $deleted = Remove-TimeSessionItem -Id $session.Id -DatabasePath $script:TestDb
            $deleted | Should -Be $true

            (Get-TimeSessionItem -Id $session.Id -DatabasePath $script:TestDb) | Should -BeNullOrEmpty
            (Get-TaskSessionLinkBySessionId -SessionId $session.Id -DatabasePath $script:TestDb).Count | Should -Be 0

            # The parent task must remain intact
            $taskStillExists = Get-TaskItem -Id $task.Id -DatabasePath $script:TestDb
            $taskStillExists | Should -Not -BeNullOrEmpty
        }
    }
}