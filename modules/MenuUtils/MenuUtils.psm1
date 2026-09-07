<#
.SYNOPSIS
    Interactive console menu and confirmation utilities.
#>

function Show-Menu {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Title = "Use Up/Down arrows to navigate, Enter to select:",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Options = @("Option A", "Option B", "Option C", "Quit")
    )

    # Fallback to standard textual prompt if host is not interactive or input is redirected
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        Write-Host $Title -ForegroundColor Blue
        for ($i = 0; $i -lt $Options.Length; $i++) {
            Write-Host ("[{0}] {1}" -f ($i + 1), $Options[$i])
        }
        $selection = Read-Host "Select an option number [1-$($Options.Length)]"
        $idx = 0
        if ([int]::TryParse($selection, [ref]$idx) -and $idx -ge 1 -and $idx -le $Options.Length) {
            $Options[$idx - 1]
            return
        }
        $Options[0]
        return
    }

    $index = 0
    $count = $Options.Length
    $longest = ($Options | Measure-Object -Property Length -Maximum).Maximum + 4

    # Hide cursor during menu rendering
    [Console]::CursorVisible = $false

    try {
        Write-Host $Title -ForegroundColor Blue

        # Pre-allocate blank lines to force any viewport scrolling beforehand
        for ($s = 0; $s -lt $count; $s++) {
            Write-Host ""
        }
        # Reposition cursor to the top of the reserved area
        [Console]::CursorTop = [Console]::CursorTop - $count
        $startTop = [Console]::CursorTop

        while ($true) {
            # Reset cursor to top of the menu options
            [Console]::SetCursorPosition(0, $startTop)

            # Render menu items with line padding to clear remnants
            for ($i = 0; $i -lt $count; $i++) {
                $line = if ($i -eq $index) {
                    " > $($Options[$i]) "
                } else {
                    "   $($Options[$i]) "
                }

                if ($i -eq $index) {
                    Write-Host ($line.PadRight($longest)) -ForegroundColor Black -BackgroundColor White
                } else {
                    Write-Host ($line.PadRight($longest)) -ForegroundColor Gray
                }
            }

            # Intercept keystroke
            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                'UpArrow'   { $index = ($index - 1 + $count) % $count }
                'DownArrow' { $index = ($index + 1) % $count }
                'Enter'     { 
                    $Options[$index]
                    return 
                }
                'Escape'    { return }
            }
        }
    }
    finally {
        # Restore cursor visibility and position below the menu
        [Console]::CursorVisible = $true
        if ($null -ne $startTop) {
            $endTop = [Math]::Min([Console]::BufferHeight - 1, $startTop + $count)
            [Console]::SetCursorPosition(0, $endTop)
        }
        Write-Host ""
    }
}

function Confirm-Action {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Message = "Would you like to proceed?"
    )

    do {
        $response = (Read-Host "$Message (Y/N)").Trim()
    } while ($response -notmatch '^(y|yes|n|no)$')

    # Emit boolean evaluation directly to pipeline
    $response -match '^(y|yes)$'
}

# Explicitly expose functions to callers
Export-ModuleMember -Function Show-Menu, Confirm-Action