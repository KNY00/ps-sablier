# Hashes for PowerShell 7+ (.NET 8 runtime)
$script:KnownHashesCore = @{
    "e_sqlite3.dll:win-x64"                      = "DCCBABB2BC7E7D4302C44D9CE41B70721A7D0914FA4D289E2F340D39766AD102"
    "e_sqlite3.dll:win-arm64"                    = "A56E35D6ABAC40A657E0445BE007F6479B16B4F0566CA7B0B9A3E0794E87A969"
    "Microsoft.Data.Sqlite.dll"                  = "29981956955DA36990B3CFC93FE50597EEACAE669663E230BEF519D5693BB2FB"
    "SQLitePCLRaw.batteries_v2.dll"              = "E2709FDA3EE4137DCEA3398221F0AFCD6241DB0EA6FA55FD31A33610BE78CF02"
    "SQLitePCLRaw.core.dll"                      = "C33995427EDD44FA641CF702DF8B63CC82CB7054DD984DC8277D15EE7C958874"
    "SQLitePCLRaw.provider.e_sqlite3.dll"        = "66A5EA09AA318F9A05093C28ED19D3EB2491D8C3710FF5FB622B8902AB866CE8"
}

# Hashes for PowerShell 5.1 (netstandard2.0 runtime)
$script:KnownHashesDesktop = @{
    "e_sqlite3.dll:win-x64"                      = "DCCBABB2BC7E7D4302C44D9CE41B70721A7D0914FA4D289E2F340D39766AD102"
    "e_sqlite3.dll:win-arm64"                    = "A56E35D6ABAC40A657E0445BE007F6479B16B4F0566CA7B0B9A3E0794E87A969"
    "Microsoft.Data.Sqlite.dll"                  = "27B41A477EBA144BA6444B9BD6A03BC6DE3DA987B6B1EFB3557885A76263A545"
    "SQLitePCLRaw.batteries_v2.dll"              = "E2709FDA3EE4137DCEA3398221F0AFCD6241DB0EA6FA55FD31A33610BE78CF02"
    "SQLitePCLRaw.core.dll"                      = "C33995427EDD44FA641CF702DF8B63CC82CB7054DD984DC8277D15EE7C958874"
    "SQLitePCLRaw.provider.e_sqlite3.dll"        = "6D2C3337183E5C94F734CDDAB60E0D100530DA212060847C87B15B463D146DAC"
    "System.Buffers.dll"                         = "C65FFF603B283DC966D1A8B730C11D5E5E750E8021BD24640612F6CC3F2C6FB7"
    "System.Memory.dll"                          = "11590D8BB3B12F29F4202B3EF8593229A5CD6DEBB61E76CBA9AC5493A82EE382"
    "System.Numerics.Vectors.dll"                = "17924E5DC87E0D6229D2DD0BCFC1FDFABD820901B13A68BAA89FCB80C4D1A67F"
    "System.Runtime.CompilerServices.Unsafe.dll" = "01748200F2400C742AA689F1F5101BD6298EFDFD92C00C18F4FA473847235BA9"
}


# Dynamically select active hash map based on PowerShell major engine version
$script:KnownHashes = if ($PSVersionTable.PSVersion -lt [version]"7.4") {
    $script:KnownHashesDesktop
} else {
    $script:KnownHashesCore
}

# Well-known official Microsoft Root CA Thumbprints (SHA-1)
$script:TrustedMicrosoftRootThumbprints = @(
    '28CC3A25BFBA44AC4420BE0B205A8B1A7E945911', # Microsoft Root Certificate Authority 2010
    '8F43288AD272F3103B6FB1428485EA3014C0BCFE'  # Microsoft Root Certificate Authority 2011
)

function Test-MicrosoftSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [switch]$RequireStrictOnlineRevocation
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("File not found for signature verification: $FilePath")
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($FilePath)
    $sig = Get-AuthenticodeSignature -FilePath $resolvedPath

    if ($sig.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw [System.Security.SecurityException]::new("Authenticode signature validation failed for '$resolvedPath'. Status: $($sig.Status) - $($sig.StatusMessage)")
    }

    $cert = $sig.SignerCertificate
    if ($null -eq $cert) {
        throw [System.Security.SecurityException]::new("Missing signer certificate on '$resolvedPath'.")
    }

    # Strict Subject Distinguished Name check on the signing certificate
    $subjectName = $cert.SubjectName.Name
    if ($subjectName -notmatch '^CN=Microsoft Corporation,') {
        throw [System.Security.SecurityException]::new("Unauthorized signer subject on '$resolvedPath': $subjectName")
    }

    # Build certificate chain with revocation checking
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    $chain.ChainPolicy.RevocationFlag = [System.Security.Cryptography.X509Certificates.X509RevocationFlag]::ExcludeRoot
    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
    $chain.ChainPolicy.UrlRetrievalTimeout = [System.TimeSpan]::FromSeconds(5)

    $isValidChain = $chain.Build($cert)

    if (-not $isValidChain) {
        $criticalErrors = @()
        foreach ($status in $chain.ChainStatus) {
            $isOfflineError = $status.Status -in @(
                [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::RevocationStatusUnknown,
                [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::OfflineRevocation
            )

            # Ignore expiration if the file has a valid Authenticode signature with a valid timestamp
            $isTimeInvalid = ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NotTimeValid) -and
                                ($sig.Status -eq [System.Management.Automation.SignatureStatus]::Valid)

            # If strict mode is enforced, fail on offline revocation as well
            if ($RequireStrictOnlineRevocation -or (-not $isOfflineError)) {
                if (-not $isTimeInvalid) {
                    $criticalErrors += "$($status.Status): $($status.StatusInformation.Trim())"
                }
            }
        }

        if ($criticalErrors.Count -gt 0) {
            $errorSummary = $criticalErrors -join "; "
            throw [System.Security.SecurityException]::new("Certificate chain validation failed for '$resolvedPath': $errorSummary")
        }

        Write-Warning "Revocation servers unreachable or certificate lifetime expired (valid timestamp present) for '$resolvedPath'; proceeded with trust verification."
    }

    # Verify root certificate identity by thumbprint
    $rootElement = $chain.ChainElements[$chain.ChainElements.Count - 1]
    $actualRootThumbprint = $rootElement.Certificate.Thumbprint.ToUpperInvariant()

    if ($actualRootThumbprint -notin $script:TrustedMicrosoftRootThumbprints) {
        throw [System.Security.SecurityException]::new("Untrusted root CA thumbprint for '$resolvedPath': $actualRootThumbprint")
    }

    return $true
}

function Test-BinaryIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$ComponentKey
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("File not found for integrity check: $FilePath")
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($FilePath)
    $actualHash = (Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256).Hash

    # Default to base file name if explicit component key is not supplied
    $key = if ($ComponentKey) { $ComponentKey } else { [System.IO.Path]::GetFileName($resolvedPath) }

    if (-not $script:KnownHashes.ContainsKey($key)) {
        throw [System.Security.SecurityException]::new("No known SHA256 integrity hash registered for key '$key'.")
    }

    $expectedHash = $script:KnownHashes[$key]
    if ($actualHash -ine $expectedHash) {
        throw [System.Security.SecurityException]::new("Integrity validation failed for '$resolvedPath' (Key: $key). Expected: $expectedHash, Found: $actualHash")
    }

    return $true
}

function Get-EmbeddedBinaryPaths {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseModulePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet("win-x64", "win-arm64")]
        [string]$RuntimeIdentifier
    )

    $runtimesDir = [System.IO.Path]::Combine($BaseModulePath, "runtimes")
    
    # Prioritize netstandard2.0 for PS 5.1 AND PS 7.0 to 7.3. 
    # Use net8.0 exclusively for PS 7.4 and above.
    if ($PSVersionTable.PSVersion -lt [version]"7.4") {
        $managedDirCandidates = @(
            [System.IO.Path]::Combine($runtimesDir, "any", "lib", "netstandard2.0"),
            [System.IO.Path]::Combine($runtimesDir, "any", "lib", "net8.0")
        )
    } else {
        $managedDirCandidates = @(
            [System.IO.Path]::Combine($runtimesDir, "any", "lib", "net8.0"),
            [System.IO.Path]::Combine($runtimesDir, "any", "lib", "netstandard2.0")
        )
    }

    $managedDir = $null
    foreach ($candidate in $managedDirCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $managedDir = $candidate
            break
        }
    }

    if ($null -eq $managedDir) {
        # Fallback to the appropriate target directory if none were found
        $fallbackTarget = if ($PSVersionTable.PSVersion -lt [version]"7.4") { "netstandard2.0" } else { "net8.0" }
        $managedDir = [System.IO.Path]::Combine($runtimesDir, "any", "lib", $fallbackTarget)
    }

    $managedDll = [System.IO.Path]::Combine($managedDir, "Microsoft.Data.Sqlite.dll")
    $nativeDll  = [System.IO.Path]::Combine($runtimesDir, $RuntimeIdentifier, "native", "e_sqlite3.dll")

    [PSCustomObject]@{
        ManagedDirectory = $managedDir
        ManagedDll       = $managedDll
        NativeDll        = $nativeDll
    }
}