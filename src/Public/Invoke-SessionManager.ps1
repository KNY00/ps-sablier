<#
.SYNOPSIS
    Interactive session management menu.

.DESCRIPTION
    Provides interactive menu options to manually record time sessions, view recent
    history, update session metadata, link sessions to tasks, or remove existing sessions.

.EXAMPLE
    .\Invoke-SessionManager.ps1
#>

[CmdletBinding()]
param (

)

# Import shared modules
Import-Module CheckDependencies -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop
Import-Module TimeUtils -ErrorAction Stop
Import-Module SessionController -ErrorAction Stop
Import-Module SessionUtils -ErrorAction Stop
Import-Module TaskController -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

Test-ProjectPrerequisite

function Invoke-ManualSessionCreation {
    Write-Host "`n--- Manual Session Entry ---" -ForegroundColor Cyan

    Write-Host "Start Date" -ForegroundColor Blue
    $startData = Read-DateTimeInteractive
    Write-Host "Unix Timestamp: $($startData.UnixTimestamp)`n"

    Write-Host "End Date" -ForegroundColor Blue
    $endData = Read-DateTimeInteractive
    Write-Host "Unix Timestamp: $($endData.UnixTimestamp)`n"

    if ($endData.UnixTimestamp -lt $startData.UnixTimestamp) {
        Show-WarningMessage "End date cannot be earlier than start date."
        return
    }

    $sessionData = [PSCustomObject]@{
        StartedAt   = $startData.UnixTimestamp
        EndedAt     = $endData.UnixTimestamp
        IsCompleted = 1
    }

    & "$PSScriptRoot\..\Private\Helpers\Invoke-SessionCreationWorkflow.ps1" -SessionData $sessionData
}

function Invoke-SessionUpdateWorkflow {
    $idInput = Read-Host "Enter Session ID to update"
    $sessionId = 0L
    if (-not [int64]::TryParse($idInput, [ref]$sessionId)) {
        Show-ErrorMessage "Invalid Session ID."
        return
    }

    $session = Get-TimeSessionItem -Id $sessionId | Select-Object -First 1
    if (-not $session) {
        Show-WarningMessage "Session #$sessionId was not found."
        return
    }

    Write-Host "`nEditing Session #$($session.id) (Current Type: $($session.type), Completed: $($session.is_completed))" -ForegroundColor Cyan

    $updateParams = @{
        Id           = $sessionId
    }

    # 1. Update Session Type
    $changeType = Show-Menu -Title "Update session type?" -Options @("Keep Current ($($session.type))", "Change Type")
    if ($changeType -eq "Change Type") {
        $newType = Select-SessionType -AllowCancel
        if ($null -ne $newType) {
            $updateParams["Type"] = $newType
        } else {
            Show-InfoMessage "Session type modification cancelled. Keeping current value."
            return
        }
    }

    # 2. Update Timestamps
    $changeDates = Show-Menu -Title "Update session timestamps?" -Options @("Keep Current Dates", "Change Start & End Dates")
    if ($changeDates -eq "Change Start & End Dates") {
        Write-Host "New Start Date:" -ForegroundColor Blue
        $newStart = Read-DateTimeInteractive
        Write-Host "New End Date:" -ForegroundColor Blue
        $newEnd = Read-DateTimeInteractive

        if ($newEnd.UnixTimestamp -lt $newStart.UnixTimestamp) {
            Show-WarningMessage "End date cannot be earlier than start date. Timestamp changes ignored."
        } else {
            $updateParams["StartedAt"] = $newStart.UnixTimestamp
            $updateParams["EndedAt"]   = $newEnd.UnixTimestamp
        }
    }

    # 3. Update Completion
    $updateParams["IsCompleted"] = Select-SessionCompletion -CurrentStatus ([int]$session.is_completed)

    # 4. Update Notes
    $newNotes = Read-SessionNotes -CurrentNotes ($session.notes)
    if ($null -ne $newNotes) {
        $updateParams["Notes"] = $newNotes
    } else {
        Show-InfoMessage "Notes modification cancelled. Keeping current value."
        return
    }

    # Apply changes
    $updated = Set-TimeSessionItem @updateParams
    if ($updated) {
        Show-SuccessMessage "Session #$sessionId updated successfully."
    } else {
        Show-ErrorMessage "Failed to update session #$sessionId."
    }
}

function Show-SessionMenu {
    $menuOptions = @(
        "Add Session Manually",
        "List Recent Sessions",
        "Update Session",
        "Link Session to Task",
        "Delete Session",
        "Exit"
    )

    while ($true) {
        Clear-Host
        $choice = Show-Menu -Title "=== Session Manager ===" -Options $menuOptions
        
        # Exit and return to caller (Start.ps1) if Escape was pressed or Exit selected
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "Exit") {
            return
        }

        switch ($choice) {
            "Add Session Manually" {
                Invoke-ManualSessionCreation
                Pause
            }

            "List Recent Sessions" {
                $sessions = Get-TimeSessionItem -Limit 15
                if ($sessions -and $sessions.Count -gt 0) {
                    $sessions | Select-Object @(
                        @{ Name = "ID"; Expression = { $_.id } },
                        @{ Name = "Type"; Expression = { $_.type } },
                        @{ Name = "Started"; Expression = { $_.started_at } },
                        @{ Name = "Ended"; Expression = { $_.ended_at } },
                        @{ Name = "Duration (m)"; Expression = { [math]::Round($_.duration_seconds / 60, 1) } },
                        @{ Name = "Done"; Expression = { if ($_.is_completed -eq 1) { "Yes" } else { "No" } } },
                        @{ Name = "Notes"; Expression = { $_.notes } }
                    ) | Format-Table -AutoSize
                } else {
                    Write-Host "No sessions found." -ForegroundColor Yellow
                }
                Pause
            }

            "Update Session" {
                Invoke-SessionUpdateWorkflow
                Pause
            }

            "Link Session to Task" {
                $sInput = Read-Host "Enter Session ID"
                $sessionId = 0L
                if ([int64]::TryParse($sInput, [ref]$sessionId)) {
                    Invoke-TaskLinkingPrompt -SessionId $sessionId
                } else {
                    Show-ErrorMessage "Invalid Session ID."
                }
                Pause
            }

            "Delete Session" {
                $sInput = Read-Host "Enter Session ID to delete"
                $sessionId = 0L
                if ([int64]::TryParse($sInput, [ref]$sessionId)) {
                    Remove-TimeSessionItem -Id $sessionId
                    Show-SuccessMessage "Session #$sessionId removed."
                } else {
                    Show-ErrorMessage "Invalid Session ID."
                }
                Pause
            }

            "Exit" {
                return
            }
        }
    }
}

Show-SessionMenu