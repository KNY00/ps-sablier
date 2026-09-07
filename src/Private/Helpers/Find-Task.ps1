<#
.SYNOPSIS
    Interactive task search helper workflow.
#>

[CmdletBinding()]
param ()

Import-Module TaskController -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop

function Read-SearchTermOrEscape {
    param (
        [string]$Prompt = "Enter task title to search (Press [Esc] to exit): "
    )

    Write-Host -NoNewline $Prompt
    $inputBuffer = ""

    while ($true) {
        $keyInfo = [Console]::ReadKey($true)

        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            Write-Host ""
            return $null
        }

        if ($keyInfo.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            return $inputBuffer
        }

        if ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
            if ($inputBuffer.Length -gt 0) {
                $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                [Console]::Write("`b `b")
            }
        }
        # Append printable characters
        elseif (-not [char]::IsControl($keyInfo.KeyChar)) {
            $inputBuffer += $keyInfo.KeyChar
            [Console]::Write($keyInfo.KeyChar)
        }
    }
}

$menuOptions = @("Search pending tasks", "Search completed tasks", "Leave")

while ($true) {
    # Prompt the user to select an action via arrow keys
    $action = Show-Menu -Title "Choose an action:" -Options $menuOptions

    # Handle Escape or explicit Leave selection
    if ([string]::IsNullOrWhiteSpace($action) -or $action -eq "Leave") {
        Write-Host "Exiting search..." -ForegroundColor Yellow
        break
    }

    # Prompt user for search input
    $searchTerm = Read-SearchTermOrEscape

    if ($null -eq $searchTerm) {
        Write-Host "Search cancelled. Exiting..." -ForegroundColor Yellow
        break
    }

    $statusFilter = if ($action -eq "Search completed tasks") { "Completed" } else { "Pending" }
    $statusLabel = $statusFilter.ToLower()

    Write-Host "Searching for $statusLabel tasks matching '$searchTerm'`n" -ForegroundColor Blue

    $tasks = Get-TaskItem -Status $statusFilter

    $results = @($tasks | Where-Object { $_.Title -like "*$searchTerm*" })

    if ($results.Count -gt 0) {
        # Render table with multi-line wrapping enabled
        $results | Format-Table -Property `
            @{ Name = "Id";        Expression = { $_.Id }; Width = 5 }, `
            @{ Name = "Title";     Expression = { $_.Title }; Width = 28 }, `
            @{ Name = "Notes";     Expression = { $_.Notes }; Width = 35 }, `
            @{ Name = "DueDate";   Expression = { if ($_.DueDate) { [DateTimeOffset]::FromUnixTimeSeconds($_.DueDate).ToLocalTime().ToString("yyyy-MM-dd HH:mm") } else { "-" } }; Width = 17 }, `
            @{ Name = "CreatedAt"; Expression = { [DateTimeOffset]::FromUnixTimeSeconds($_.CreatedAt).ToLocalTime().ToString("yyyy-MM-dd HH:mm") }; Width = 17 } `
            -Wrap
    } else {
        Write-Host "No $statusLabel tasks found matching '$searchTerm'." -ForegroundColor Yellow
    }

    Write-Host "----------------------------------------`n"
}