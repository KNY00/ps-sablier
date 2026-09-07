# Ensure required dependencies are imported if running standalone outside module path
$requiredModules = @('UiNotificationUtils', 'SqliteUtils', 'SqliteInstaller', 'MenuUtils')
foreach ($moduleName in $requiredModules) {
    if (-not (Get-Module -Name $moduleName)) {
        # Attempt standard import first; fallback to sibling directory relative to PSScriptRoot
        try {
            Import-Module $moduleName -ErrorAction Stop
        }
        catch {
            $siblingManifest = Join-Path (Split-Path -Parent $PSScriptRoot) "$moduleName\$moduleName.psd1"
            if (Test-Path -LiteralPath $siblingManifest) {
                Import-Module $siblingManifest -ErrorAction Stop
            }
            else {
                throw "Required dependency module '$moduleName' could not be resolved."
            }
        }
    }
}

<#
.SYNOPSIS
    Inspects tools/bin directory, verifies it contains binaries, and appends it to PATH.
#>
function Initialize-ProjectEnvironment {
    [CmdletBinding()]
    param ()

    # Resolve project root from module location
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $toolsBinDir = Join-Path $projectRoot "tools\bin"

    # Only register tools\bin if the directory exists AND contains executable files
    if (Test-Path -LiteralPath $toolsBinDir) {
        $hasBinaries = Get-ChildItem -LiteralPath $toolsBinDir -Filter "*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($hasBinaries) {
            $currentPaths = $env:PATH -split [System.IO.Path]::PathSeparator

            if ($toolsBinDir -notin $currentPaths) {
                # Prepend to PATH so local project binaries take priority
                $env:PATH = "$toolsBinDir$([System.IO.Path]::PathSeparator)$env:PATH"
            }
        }
    }
}

<#
.SYNOPSIS
    Verifies if a given application executable is present in PATH.

.DESCRIPTION
    Checks whether the specified executable can be resolved in the system PATH.
    Returns $true if present, or $false if missing.

.PARAMETER Name
    The name of the executable to search for.

.OUTPUTS
    [bool] True if the executable is found in PATH, false otherwise.

.EXAMPLE
    Test-CommandInPath -Name "timer"
#>
function Test-CommandInPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue)) {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Verifies that the timer binary is available in PATH.

.DESCRIPTION
    Delegates to Test-CommandInPath to ensure the 'timer' executable is accessible.
    Throws an exception if 'timer' is missing from PATH.

.EXAMPLE
    Test-Timer
#>
function Test-Timer {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (-not (Test-CommandInPath -Name "timer")) {
        throw "The 'timer' binary was not found in Path."
    }

    Write-Output $true
    return
}

<#
.SYNOPSIS
    Verifies if the SQLite CLI executable is available in PATH.

.DESCRIPTION
    Checks whether the specified SQLite command-line executable can be resolved in PATH.
    Displays an error message and returns $false if missing, otherwise returns $true.

.PARAMETER Executable
    The name or path of the SQLite executable to locate. Defaults to "sqlite3".

.OUTPUTS
    [bool] True if the SQLite CLI executable exists in PATH, false otherwise.

.EXAMPLE
    Test-SqliteCli
    Test-SqliteCli -Executable "sqlite3"
#>
function Test-SqliteCli {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Executable = "sqlite3"
    )

    if (-not (Get-Command $Executable -ErrorAction SilentlyContinue)) {
        Show-ErrorMessage "The '$Executable' command-line tool was not found in your PATH."
        $false
        return
    }
    $true
}

<#
.SYNOPSIS
    Validates all prerequisite dependencies for ps-sablier.

.DESCRIPTION
    Performs pre-flight checks ensuring both the SQLite backend (sqlite3 CLI or PSSQLite)
    and the external timer binary are accessible before executing workflows.

.EXAMPLE
    Test-ProjectPrerequisite
#>
function Test-ProjectPrerequisite {
    [CmdletBinding()]
    param ()

    # Check and prepend tools\bin to PATH if binaries are already present there
    Initialize-ProjectEnvironment

    try {
        Test-SqliteAvailable -ErrorAction Stop | Out-Null
        
        $DatabasePathExist = Assert-SqliteDatabasePath

        if (-not $DatabasePathExist) {
            throw "Missing database file."
        }

        Test-Timer -ErrorAction Stop | Out-Null
    }
    catch {
        # Capture the original error message
        $originalError = $_.Exception.Message

        # Append actionable guidance
        Write-Host ""
        Write-Warning "Run ./bootstrap.ps1 to install dependencies."

        # Throw the combined error message to halt execution
        throw "$originalError"
    }
}

function Assert-PSSqlite {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (Test-PSSqliteInstalled) {
        return $true
    }

    Show-InfoMessage "PowerShell module 'PSSQLite' is not installed."
    $shouldInstall = Confirm-Action -Message "Would you like to install 'PSSQLite' now?"

    if ($shouldInstall) {
        Show-InfoMessage "Installing PowerShell module 'PSSQLite' from PSGallery..."
        $installed = Install-PSSqlite

        if ($installed) {
            Show-SuccessMessage "Module 'PSSQLite' installed successfully."
        } else {
            Show-ErrorMessage "Failed to install 'PSSQLite' module." -Details $_.Exception.Message
        }

        if ($installed -and (Test-PSSqliteInstalled)) {
            Import-Module -Name "PSSQLite" -ErrorAction SilentlyContinue
            return $true
        }
    }

    Show-ErrorMessage "Workflow stopped: 'PSSQLite' module is required but not installed."
    throw "Missing required dependency: PSSQLite module."
}


function Write-SqliteError {
    Show-ErrorMessage "No valid SQLite backend found. Please install sqlite3 or PSSQLite."

    throw "Missing SQLite backend."
}

function Test-SqliteAvailable {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $backend = Get-SqliteBackend

    if ($backend -eq "None") {
        Write-SqliteError
    }

    $backend
}

function Confirm-SqliteAvailable {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $backend = Get-SqliteBackend
    if ($backend -eq "None") {
        Show-InfoMessage "Neither 'sqlite3' CLI nor 'PSSQLite' module was found."
        Assert-PSSqlite
        $backend = Get-SqliteBackend
    }

    if ($backend -eq "None") {
        Write-SqliteError
    }

    $backend
}

Export-ModuleMember -Function `
    Initialize-ProjectEnvironment, `
    Test-Timer, `
    Test-ProjectPrerequisite, `
    Test-SqliteAvailable, `
    Confirm-SqliteAvailable
