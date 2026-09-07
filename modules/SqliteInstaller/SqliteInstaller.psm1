function Install-SqliteCli {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    process {
        # Check target architecture
        $arch = $env:PROCESSOR_ARCHITECTURE
        $targetScript = $null

        if ($arch -eq 'ARM64') {
            $targetScript = Join-Path -Path $PSScriptRoot -ChildPath 'scripts/Install-Arm64.ps1'
        }
        elseif ($arch -in @('AMD64', 'x86_64')) {
            $targetScript = Join-Path -Path $PSScriptRoot -ChildPath 'scripts/Install-Amd64.ps1'
        }
        else {
            throw "Unsupported system architecture: $arch. Only AMD64 and ARM64 are supported."
        }

        if (-not (Test-Path -Path $targetScript)) {
            throw "Installation script could not be found at: $targetScript"
        }

        # Execute the architecture-specific script
        & $targetScript -FilePath $FilePath
    }
}


function Install-PSSqlite {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    try {
        Install-Module -Name "PSSQLite" -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-PSSqliteInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $module = Get-Module -ListAvailable -Name "PSSQLite" -ErrorAction SilentlyContinue
    [bool]$module
}

<#
.SYNOPSIS
    Determines the available SQLite backend mechanism on the system.

.DESCRIPTION
    Checks if the sqlite3 CLI tool or the PSSQLite PowerShell module is installed,
    returning the appropriate backend type ('CLI', 'PSSQLite', or 'None').

.OUTPUTS
    [string] The name of the available backend ('CLI', 'PSSQLite', or 'None').
#>
function Get-SqliteBackend {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    if (Get-Command -Name "sqlite3" -CommandType Application -ErrorAction SilentlyContinue) {
        "CLI"
        return
    }

    if (Test-PSSqliteInstalled) {
        "PSSQLite"
        return
    }

    "None"
}


Export-ModuleMember -Function `
    Install-SqliteCli, `
    Install-PSSqlite,
    Test-PSSqliteInstalled,
    Get-SqliteBackend