<#
.SYNOPSIS
    Interactive CLI utilities for managing Pomodoro and tracking sessions.

.DESCRIPTION
    Provides terminal-based prompts and interactive workflows for choosing session types,
    editing session notes, setting completion status, and linking time sessions to tasks.
#>

# Restrictive list of valid session types
$script:AllowedSessionTypes = @("pomodoro_work", "short_break", "long_break", "free_track")

<#
.SYNOPSIS
    Reads an interactive line from console allowing user to cancel via the Escape key,
    with full arrow-key cursor navigation support.
#>
function Read-ConsoleLineOrEscape {
    param (
        [string]$Prompt = ""
    )

    # Fallback to standard input if not in an interactive terminal
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        return (Read-Host $Prompt)
    }

    if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
        Write-Host -NoNewline $Prompt
    }

    $inputBuffer = ""
    $cursorIndex = 0

    # Store the origin position where the user input starts
    $originLeft = [Console]::CursorLeft
    $originTop  = [Console]::CursorTop

    # Helper closure to calculate and set cursor position with wrap-around support
    $setCursor = {
        param([int]$index)
        $width = [Console]::BufferWidth
        
        # Calculate horizontal and vertical offsets
        $left = ($originLeft + $index) % $width
        $top = $originTop + [math]::Floor(($originLeft + $index) / $width)
        
        # Ensure we do not crash by exceeding the buffer height
        if ($top -ge [Console]::BufferHeight) {
            $top = [Console]::BufferHeight - 1
        }
        [Console]::SetCursorPosition($left, $top)
    }

    # Helper closure to redraw the current input buffer
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
            # Move cursor backward
            if ($cursorIndex -gt 0) {
                $cursorIndex--
                &$setCursor $cursorIndex
            }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::RightArrow) {
            # Move cursor forward
            if ($cursorIndex -lt $inputBuffer.Length) {
                $cursorIndex++
                &$setCursor $cursorIndex
            }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Home) {
            # Jump to the beginning of the line
            $cursorIndex = 0
            &$setCursor $cursorIndex
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::End) {
            # Jump to the end of the line
            $cursorIndex = $inputBuffer.Length
            &$setCursor $cursorIndex
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
            # Remove character immediately before the cursor
            if ($cursorIndex -gt 0) {
                $inputBuffer = $inputBuffer.Remove($cursorIndex - 1, 1)
                $cursorIndex--
                &$redraw
            }
        }
        elseif ($keyInfo.Key -eq [ConsoleKey]::Delete) {
            # Remove character exactly at the cursor position
            if ($cursorIndex -lt $inputBuffer.Length) {
                $inputBuffer = $inputBuffer.Remove($cursorIndex, 1)
                &$redraw
            }
        }
        elseif (-not [char]::IsControl($keyInfo.KeyChar)) {
            # Insert typed character at the current cursor index
            $inputBuffer = $inputBuffer.Insert($cursorIndex, $keyInfo.KeyChar)
            $cursorIndex++
            &$redraw
        }
    }
}

<#
.SYNOPSIS
    Prompts the user to interactively select a session type.

.DESCRIPTION
    Presents an interactive menu populated with predefined session types.
    Falls back to the provided default value if the selection is cancelled (Escape),
    unless -AllowCancel is specified.

.PARAMETER Default
    The fallback session type if selection is aborted. Defaults to 'pomodoro_work'.

.PARAMETER AllowCancel
    If set, returns $null when Escape is pressed instead of using the Default fallback.

.OUTPUTS
    [string] The selected session type, or $null if cancelled with -AllowCancel.
#>
function Select-SessionType {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("pomodoro_work", "short_break", "long_break", "free_track")]
        [string]$Default = "pomodoro_work",

        [Parameter(Mandatory = $false)]
        [switch]$AllowCancel
    )

    $options = $script:AllowedSessionTypes
    $choice = Show-Menu -Title "Select Session Type:" -Options $options

    # Handle user cancellation (Escape key in Show-Menu)
    if ([string]::IsNullOrWhiteSpace($choice)) {
        if ($AllowCancel) {
            return $null
        }
        $choice = $Default
    }

    Write-Host "Selected: $choice"
    Write-Output $choice
}

<#
.SYNOPSIS
    Reads or updates session notes interactively.

.DESCRIPTION
    Prompts the user to enter new notes or retain existing ones.
    Supports cancellation via the Escape key (returns $null).

.PARAMETER CurrentNotes
    The existing session notes. If empty, the user is prompted for a fresh note.

.OUTPUTS
    [string] The newly entered or existing note string, or $null if cancelled via Escape.
#>
function Read-SessionNotes {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$CurrentNotes = ""
    )

    if ([string]::IsNullOrWhiteSpace($CurrentNotes)) {
        return (Read-ConsoleLineOrEscape -Prompt "Enter session notes (optional, [Esc] to cancel): ")
    }

    Show-InfoMessage "Current notes: '$CurrentNotes'"
    $newNotes = Read-ConsoleLineOrEscape -Prompt "Enter new notes (leave blank to keep current, [Esc] to cancel): "

    if ($null -eq $newNotes) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($newNotes)) {
        return $CurrentNotes
    }

    Write-Output $newNotes
}

<#
.SYNOPSIS
    Prompts the user to select the completion status of a session.

.DESCRIPTION
    Displays a menu offering Completed (1) or Incomplete (0) options.

.PARAMETER CurrentStatus
    The current completion status (1 for completed, 0 for incomplete). Defaults to 1.

.OUTPUTS
    [int] 1 if marked completed, 0 if marked incomplete.
#>
function Select-SessionCompletion {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, 1)]
        [int]$CurrentStatus = 1
    )

    $currentLabel = if ($CurrentStatus -eq 1) { "Completed" } else { "Incomplete" }
    $options = @("Completed (1)", "Incomplete (0)")
    $choice = Show-Menu -Title "Select completion status (Current: $currentLabel):" -Options $options

    if ($choice -match "Completed") {
        return 1
    }
    
    return 0
}

<#
.SYNOPSIS
    Associates a specific task with a time session in the database.

.DESCRIPTION
    Validates task existence, checks for existing links, warns about potential replacements,
    and updates the pivot table accordingly.

.PARAMETER TaskId
    The ID of the task to associate.

.PARAMETER SessionId
    The ID of the time session.

.OUTPUTS
    [bool] $true if successfully linked, otherwise $false.
#>
function Complete-TaskSessionLink {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [long]$TaskId,

        [Parameter(Mandatory = $true)]
        [long]$SessionId
    )

    # Validate that the target task exists using int64 ID
    $task = Get-TaskItem -Id ([int64]$TaskId) | Select-Object -First 1

    if (-not $task) {
        Show-ErrorMessage "Task with ID $TaskId was not found in database."
        return $false
    }

    # Check if this session is already linked to an existing task in the pivot table
    $existingLink = Get-TaskSessionLinkBySessionId -SessionId $SessionId | Select-Object -First 1

    if ($existingLink) {
        # Resolve task title using PascalCase property TaskTitle, falling back to task_title if raw object
        $linkTitle = if ($null -ne $existingLink.TaskTitle) { $existingLink.TaskTitle } else { $existingLink.task_title }

        # Display warning message specifying the existing task title
        Show-WarningMessage "This action will replace the existing association with task '$linkTitle'."

        # Abort execution if user cancels or returns false
        if (-not (Confirm-Action)) {
            Show-InfoMessage "Aborted."
            return $false
        }

        # Remove prior association before inserting the new record into the pivot table
        $null = Remove-TaskSessionLinkBySessionId -SessionId $SessionId
    }

    # Link task and session using controller function
    $success = Add-TaskSessionLink -TaskId $TaskId -SessionId $SessionId

    if ($success) {
        # Resolve task title using PascalCase property Title, falling back to title
        $taskTitle = if ($null -ne $task.Title) { $task.Title } else { $task.title }
        Show-InfoMessage "Task: $taskTitle"
        Show-SuccessMessage "Successfully linked Task ID $TaskId to Session ID $SessionId."
        return $true
    } else {
        Show-ErrorMessage "Failed to insert record for Task ID $TaskId and Session ID $SessionId."
        return $false
    }
}

<#
.SYNOPSIS
    Interactively prompts the user to associate an active session with a task.

.DESCRIPTION
    Asks the user if they wish to link the session, provides a task search utility,
    and forwards user inputs to Complete-TaskSessionLink. Supports cancellation via the Escape key.

.PARAMETER SessionId
    The ID of the time session to be linked.
#>
function Invoke-TaskLinkingPrompt {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [long]$SessionId
    )

    $options = @("yes", "no")
    $isLinked = Show-Menu -Title "Would you like to link session #$SessionId to a task?" -Options $options

    if ($isLinked -ne 'yes') {
        return
    }

    Show-SuccessMessage "Selected: $isLinked"

    # Locate and run task finder from the project root task folder
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $findTaskScript = Join-Path $projectRoot "src\Private\Helpers\Find-Task.ps1"

    if (Test-Path -Path $findTaskScript) {
        Write-Host "Search for the task by title. When finished, enter its ID below."
        & $findTaskScript
    } else {
        Show-WarningMessage "Find-Task helper script not found at '$findTaskScript'."
    }

    # Interactively read Task ID with Escape key cancellation support
    $taskIdInput = Read-ConsoleLineOrEscape -Prompt "Enter the Task ID to link (numeric only, [Esc] to cancel): "

    # Exit gracefully if user pressed Escape
    if ($null -eq $taskIdInput) {
        Show-InfoMessage "Task linking cancelled."
        return
    }

    $parsedTaskId = [int64]0
    if (-not [int64]::TryParse($taskIdInput, [ref]$parsedTaskId)) {
        Show-ErrorMessage "Invalid Task ID. Please enter a valid integer."
        return
    }

    # Invoke linking logic
    $null = Complete-TaskSessionLink -TaskId $parsedTaskId -SessionId $SessionId
}

# Explicitly expose functions to callers
Export-ModuleMember -Function `
    Select-SessionType, `
    Read-SessionNotes, `
    Select-SessionCompletion, `
    Complete-TaskSessionLink, `
    Invoke-TaskLinkingPrompt