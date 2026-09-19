# Load Windows platform helper securely
$platformProvider = Join-Path -Path:$PSScriptRoot -ChildPath:"SQLitePlatform.Windows.ps1" ;
if (-not (Test-Path -LiteralPath:$platformProvider -PathType:Leaf)) {
    throw [System.IO.FileNotFoundException]::new("Platform provider script not found: $platformProvider") ;
}
. $platformProvider ;

<#
.SYNOPSIS
    Enforces that the execution environment is strictly Windows x64 or ARM64.
#>
function Assert-WindowsArchitectureSupport {
    [CmdletBinding()]
    param()

    $isPlatformWindows = if ($PSVersionTable.PSVersion.Major -ge 6) {
        [bool]$IsWindows ;
    } else {
        [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT ;
    }

    if (-not $isPlatformWindows) {
        throw [System.PlatformNotSupportedException]::new("This module is strictly restricted to Windows.") ;
    }

    $arch = $env:PROCESSOR_ARCHITECTURE ;
    switch ($arch) {
        { $_ -in @('AMD64', 'x86_64') } {
            return "win-x64" ;
        }
        'ARM64' {
            return "win-arm64" ;
        }
        Default {
            throw [System.PlatformNotSupportedException]::new("Unsupported processor architecture: '$arch'.") ;
        }
    }
}

<#
.SYNOPSIS
    Ensures Win32 LoadLibrary method definition is registered for PowerShell 5.1.
#>
function Ensure-Win32Loader {
    if (-not ([System.Management.Automation.PSTypeName]'Win32.NativeMethods').Type) {
        Add-Type -MemberDefinition @"
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr LoadLibrary(string lpLibFileName);
"@ -Name:"NativeMethods" -Namespace:"Win32" ;
    }
}

<#
.SYNOPSIS
    Initializes and loads the embedded SQLite database driver.
#>
function Initialize-SqliteDriver {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseDirectory = $PSScriptRoot
    )

    # Fallback dot-sourcing in case the module scope was lost or corrupted during paste
    if (-not (Get-Command -Name "Get-EmbeddedBinaryPaths" -ErrorAction:SilentlyContinue)) {
        . (Join-Path -Path:$PSScriptRoot -ChildPath:"SQLitePlatform.Windows.ps1") ;
    }

    # 1. Check if Microsoft.Data.Sqlite is already loaded
    $loadedAssembly = $null ;
    foreach ($asm in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
        if ($asm.GetName().Name -eq "Microsoft.Data.Sqlite") {
            $loadedAssembly = $asm ;
            break ;
        }
    }

    if ($null -ne $loadedAssembly) {
        Write-Verbose -Message:"Microsoft.Data.Sqlite is already active in this session." ;
        return $true ;
    }

    # 2. Platform and architecture validation
    $targetRid = Assert-WindowsArchitectureSupport ;

    # 3. Resolve canonical embedded binary paths
    $resolvedBase = [System.IO.Path]::GetFullPath($BaseDirectory) ;
    $binPaths = Get-EmbeddedBinaryPaths -BaseModulePath:$resolvedBase -RuntimeIdentifier:$targetRid ;

    if (-not (Test-Path -LiteralPath:$binPaths.ManagedDll -PathType:Leaf)) {
        throw [System.IO.FileNotFoundException]::new("Embedded assembly 'Microsoft.Data.Sqlite.dll' was not found at: $($binPaths.ManagedDll)") ;
    }

    if (-not (Test-Path -LiteralPath:$binPaths.NativeDll -PathType:Leaf)) {
        throw [System.IO.FileNotFoundException]::new("Embedded native library 'e_sqlite3.dll' was not found for target '$targetRid' at: $($binPaths.NativeDll)") ;
    }

    # 4. Cryptographic and integrity verification
    Write-Verbose -Message:"Verifying Microsoft Authenticode signature for Microsoft.Data.Sqlite.dll..." ;
    $null = Test-MicrosoftSignature -FilePath:$binPaths.ManagedDll ;

    Write-Verbose -Message:"Verifying integrity for native e_sqlite3.dll ($targetRid)..." ;
    $null = Test-BinaryIntegrity -FilePath:$binPaths.NativeDll -ComponentKey:("e_sqlite3.dll:" + $targetRid) ;

    # 5. Preload native SQLite library into process memory
    Ensure-Win32Loader ;
    $loadResult = [Win32.NativeMethods]::LoadLibrary($binPaths.NativeDll) ;
    if ($loadResult -eq [System.IntPtr]::Zero) {
        $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() ;
        throw [System.DllNotFoundException]::new("Failed to load native library '$($binPaths.NativeDll)'. Win32 Error: $lastError") ;
    }

    # 6. Assembly Resolver (Including your LoadFrom fix for System.Memory)
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $script:SQLiteManagedDir = $binPaths.ManagedDirectory ;

        if (-not $script:AssemblyResolverRegistered) {
            $resolverDelegate = [System.ResolveEventHandler]{
                param($sender, $resolveArgs)

                $requestedName = ($resolveArgs.Name -split ',')[0].Trim() ;

                foreach ($a in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                    if ($a.GetName().Name -eq $requestedName) {
                        return $a ;
                    }
                }

                if (-not [string]::IsNullOrWhiteSpace($script:SQLiteManagedDir)) {
                    $targetDll = [System.IO.Path]::Combine($script:SQLiteManagedDir, "$requestedName.dll") ;
                    if ([System.IO.File]::Exists($targetDll)) {
                        return [System.Reflection.Assembly]::LoadFrom($targetDll) ;
                    }
                }

                return [System.Reflection.Assembly]$null ;
            }

            [System.AppDomain]::CurrentDomain.add_AssemblyResolve($resolverDelegate) ;
            $script:AssemblyResolverRegistered = $true ;
        }
    }

    # 7. Ordered dependency preloading (using LoadFrom)
    $preloadDlls = @(
        "System.Runtime.CompilerServices.Unsafe.dll",
        "System.Numerics.Vectors.dll",
        "System.Buffers.dll",
        "System.Memory.dll",
        "SQLitePCLRaw.core.dll",
        "SQLitePCLRaw.provider.e_sqlite3.dll",
        "SQLitePCLRaw.batteries_v2.dll"
    )

    foreach ($dllName in $preloadDlls) {
        $dllFullPath = [System.IO.Path]::Combine($binPaths.ManagedDirectory, $dllName) ;
        if ([System.IO.File]::Exists($dllFullPath)) {
            $null = [System.Reflection.Assembly]::LoadFrom($dllFullPath) ;
        }
    }

    # 8. Load main Microsoft.Data.Sqlite assembly
    $null = [System.Reflection.Assembly]::LoadFrom($binPaths.ManagedDll) ;

    # 9. Initialize SQLitePCLRaw batteries provider
    try {
        [SQLitePCL.Batteries_V2]::Init() ;
    }
    catch {
        Write-Verbose -Message:"SQLitePCL.Batteries_V2 initialization note: $_" ;
    }

    Write-Host -Object:"SQLite driver ready on $targetRid (embedded)." -ForegroundColor:Green ;
    return $true ;
}

Export-ModuleMember -Function Initialize-SqliteDriver;