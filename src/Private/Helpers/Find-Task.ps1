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
    $cursorIndex = 0

    # Store origin position
    $originLeft = [Console]::CursorLeft
    $originTop  = [Console]::CursorTop

    # Helper closure to calculate and set cursor position safely
    $setCursor = {
        param([int]$index)
        $width = [Console]::BufferWidth
        
        $left = ($originLeft + $index) % $width
        $top = $originTop + [math]::Floor(($originLeft + $index) / $width)
        
        if ($top -ge [Console]::BufferHeight) {
            $top = [Console]::BufferHeight - 1
        }
        [Console]::SetCursorPosition($left, $top)
    }

    # Helper closure to redraw the search buffer
    $redraw = {
        &$setCursor 0
        Write-Host -NoNewline "$inputBuffer "
        &$setCursor $cursorIndex
    }

    while ($true) {
        $keyInfo = [Console]::ReadKey($true)

        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            Write-Host ""
            return $null
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            return $inputBuffer
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::LeftArrow) {
            if ($cursorIndex -gt 0) {
                $cursorIndex--
                &$setCursor $cursorIndex
            }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::RightArrow) {
            if ($cursorIndex -lt $inputBuffer.Length) {
                $cursorIndex++
                &$setCursor $cursorIndex
            }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Home) {
            $cursorIndex = 0
            &$setCursor $cursorIndex
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::End) {
            $cursorIndex = $inputBuffer.Length
            &$setCursor $cursorIndex
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
            if ($cursorIndex -gt 0) {
                $inputBuffer = $inputBuffer.Remove($cursorIndex - 1, 1)
                $cursorIndex--
                &$redraw
            }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Delete) {
            if ($cursorIndex -lt $inputBuffer.Length) {
                $inputBuffer = $inputBuffer.Remove($cursorIndex, 1)
                &$redraw
            }
        }
        elseif (-not [char]::IsControl($keyInfo.KeyChar)) {
            $inputBuffer = $inputBuffer.Insert($cursorIndex, $keyInfo.KeyChar)
            $cursorIndex++
            &$redraw
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