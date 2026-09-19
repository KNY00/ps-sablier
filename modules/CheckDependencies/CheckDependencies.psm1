<#
.SYNOPSIS
    Manages module dependencies, environment initialization, and prerequisite validation for the project.

.DESCRIPTION
    This module ensures that all required utility and SQLite modules are loaded, configures the
    system PATH with local project binaries, and validates SQLite and database prerequisites.
#>

# Ensure required dependencies are imported
$requiredModules = @('UiNotificationUtils', 'SqliteUtils', 'SqliteInstaller', 'SQLiteLoader', 'MenuUtils')

foreach ($moduleName in $requiredModules) {
    if (-not (Get-Module -Name $moduleName)) {
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
    Initializes the project environment paths.

.DESCRIPTION
    Checks if the project's local 'tools\bin' directory contains executables and prepends
    it to the session's PATH variable if not already present.
#>
function Initialize-ProjectEnvironment {
    [CmdletBinding()]
    param ()

    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $toolsBinDir = Join-Path $projectRoot "tools\bin"

    if (Test-Path -LiteralPath $toolsBinDir) {
        $hasBinaries = Get-ChildItem -LiteralPath $toolsBinDir -Filter "*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hasBinaries) {
            $currentPaths = $env:PATH -split [System.IO.Path]::PathSeparator
            if ($toolsBinDir -notin $currentPaths) {
                $env:PATH = "$toolsBinDir$([System.IO.Path]::PathSeparator)$env:PATH"
            }
        }
    }
}

<#
.SYNOPSIS
    Tests whether a given command exists in the system PATH.
#>
function Test-CommandInPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][string]$Name)

    return [bool](Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    Tests whether the 'timer' binary is available in the environment.
#>
function Test-Timer {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (-not (Test-CommandInPath -Name "timer")) {
        throw "The 'timer' binary was not found in Path."
    }

    return $true
}

<#
.SYNOPSIS
    Outputs a standardized error message when SQLite is missing and throws an exception.
#>
function Write-SqliteError {
    Show-ErrorMessage "No valid .NET SQLite library found. Embedded Microsoft.Data.Sqlite is missing."
    throw "Missing SQLite backend (.NET)."
}

function Test-SqliteAvailable {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    # Only .NET implementation presence guarantees availability
    if (-not (Test-SqliteDotNetInstalled)) {
        Write-SqliteError
    }

    # Initialize driver in session
    Initialize-SqliteDriver | Out-Null
    return "DotNet"
}

<#
.SYNOPSIS
    Confirms SQLite availability, offering to install it interactively if missing.
#>
function Confirm-SqliteAvailable {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    if (-not (Test-SqliteDotNetInstalled)) {
        Show-InfoMessage "Embedded .NET SQLite assemblies were not found."
        
        $shouldInstall = Confirm-Action -Message "Would you like to download and install embedded .NET SQLite DLLs now?"
        
        if ($shouldInstall) {
            $success = Install-SqliteDotNet
            
            if (-not $success) {
                Write-SqliteError
            }
            Show-SuccessMessage "Embedded .NET SQLite assemblies installed successfully."
        } else {
            Write-SqliteError
        }
    }

    Initialize-SqliteDriver | Out-Null
    return "DotNet"
}

<#
.SYNOPSIS
    Verifies all necessary project prerequisites, including environment setup, SQLite availability, and database path.
#>
function Test-ProjectPrerequisite {
    [CmdletBinding()]
    param ()

    Initialize-ProjectEnvironment

    try {
        Test-SqliteAvailable -ErrorAction Stop | Out-Null
        
        $databasePathExist = Assert-SqliteDatabasePath
        if (-not $databasePathExist) {
            throw "Missing database file."
        }
    }
    catch {
        $originalError =$_.Exception.Message
        Write-Host ""
        Write-Warning "Run ./bootstrap.ps1 to initialize the database or restore project dependencies."
        throw "$originalError"
    }
}

Export-ModuleMember -Function `
    Initialize-ProjectEnvironment, `
    Test-Timer, `
    Test-ProjectPrerequisite, `
    Test-SqliteAvailable