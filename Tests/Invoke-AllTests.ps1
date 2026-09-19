<#
.SYNOPSIS
    Runs all Pester unit and regression tests with explicit version isolation.
.DESCRIPTION
    Ensures Pester version 6 is loaded, preventing other versions
    from being used. Prompts user to manually install Pester if missing.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Detailed', 'Normal', 'Minimal', 'None')]
    [string]$Output = 'Detailed'
)

# Function to ensure Pester version 6.x is available and loaded
function Assert-PesterEnvironment {
    $isCore = ($PSVersionTable.PSVersion.Major -ge 7)

    # Unload any active Pester module from current memory
    Get-Module -Name Pester | Remove-Module -Force -ErrorAction SilentlyContinue

    # Ensure user module directory is in PSModulePath
    $userModulesDir = if ($isCore) {
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules"
    } else {
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules"
    }

    $currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    if ($userModulesDir -notin $currentPaths -and (Test-Path -LiteralPath $userModulesDir)) {
        $env:PSModulePath = "$userModulesDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    }

    # Reset command resolution cache safely via reflection if internal type is present
    try {
        $cmdDiscoveryType = [System.Management.Automation.PSObject].Assembly.GetType('System.Management.Automation.CommandDiscovery')
        if ($null -ne $cmdDiscoveryType) {
            $resetMethod = $cmdDiscoveryType.GetMethod('ResetLookupCache', [System.Reflection.BindingFlags]'NonPublic, Public, Static')
            if ($null -ne $resetMethod) {
                $null = $resetMethod.Invoke($null, $null)
            }
        }
    }
    catch {
        # Fallback silently if cache reset is not accessible
    }

    # Search for an installed version matching Major version 6
    $availablePester = Get-Module -Name Pester -ListAvailable -Refresh |
        Where-Object { $_.Version.Major -eq 6 } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    # If no compatible version is found, prompt user to download/install manually with shortcut command
    if (-not $availablePester) {
        Write-Warning "Pester version 6.x was not found."
        Write-Host "Please install Pester v6 manually using the following command shortcut:`n" -ForegroundColor Yellow
        Write-Host "    Install-Module -Name Pester -RequiredVersion 6.0.0 -Scope CurrentUser -Force -SkipPublisherCheck`n" -ForegroundColor Cyan
        return $false
    }

    # Fallback disk search if module path resolution failed
    if (-not $availablePester) {
        $candidatePaths = @(
            (Join-Path $userModulesDir "Pester"),
            (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) "PowerShell\Modules\Pester")
        )

        foreach ($dir in $candidatePaths) {
            if (Test-Path -LiteralPath $dir) {
                $manifest = Get-ChildItem -Path $dir -Filter "Pester.psd1" -Recurse -File | 
                    Select-Object -First 1
                if ($manifest) {
                    $manifestData = Import-PowerShellDataFile -Path $manifest.FullName
                    $ver = [version]$manifestData.ModuleVersion
                    if ($ver.Major -eq 6) {
                        Import-Module -Name $manifest.FullName -Force -ErrorAction Stop
                        Write-Host "Imported Pester $ver from fallback path: $($manifest.FullName)" -ForegroundColor Green
                        return $true
                    }
                }
            }
        }

        Write-Error "Could not resolve Pester (v6.x)."
        return $false
    }

    # Import the detected compatible module manifest
    Write-Host "Importing Pester $($availablePester.Version) from '$($availablePester.Path)'..." -ForegroundColor Cyan
    Import-Module -Name $availablePester.Path -Force -ErrorAction Stop
    return $true
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TestsDir = Join-Path $ProjectRoot "Tests"

# Ensure target Pester is loaded
$pesterReady = Assert-PesterEnvironment
if (-not $pesterReady) {
    exit 1
}

# Ensure local project modules directory is registered in PSModulePath
$ModulesDir = Join-Path $ProjectRoot "modules"
$currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
if ($ModulesDir -notin $currentPaths) {
    $env:PSModulePath = "$ModulesDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
}

# Locate all test files
$testFiles = Get-ChildItem -Path $TestsDir -Filter "*.Tests.ps1" -File

if (-not $testFiles -or $testFiles.Count -eq 0) {
    Write-Warning "No test files (*.Tests.ps1) found in '$TestsDir'."
    return $false
}

Write-Host "`nRunning Pester test suite with Pester $((Get-Module Pester).Version)..." -ForegroundColor Cyan

try {
    # Execution for Pester 6
    $config = [PesterConfiguration]::Default
    $config.Run.Path = @($testFiles.FullName)
    $config.Run.PassThru = $true
    $config.Output.Verbosity = $Output
    
    $result = Invoke-Pester -Configuration $config

    # Safely determine the failed count
    $failedCount = 0
    if ($null -ne $result) {
        if ($result -is [array]) {
            $failedCount = ($result | Measure-Object -Property FailedCount -Sum).Sum
        } elseif ($result.PSObject.Properties.Name -contains 'FailedCount') {
            $failedCount = [int]$result.FailedCount
        }
    }

    if ($failedCount -gt 0) { exit 1 } else { exit 0 }
}
catch {
    Write-Error "Test execution failed: $_"
    exit 1
}