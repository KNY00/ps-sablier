Import-Module CheckDependencies -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop

# Initialize PATH with local bin if present
Initialize-ProjectEnvironment

# Check if timer executable is already available in PATH
if (Get-Command -Name "timer" -CommandType Application -ErrorAction SilentlyContinue) {
    Show-SuccessMessage "'timer' binary is already available in PATH. Skipping download."
    return
}

# Parameters
$version = "1.4.6"
$repo = "caarlos0/timer"
$tag = "v$version"

# Trusted SHA256 checksums from the official checksums.txt release manifest
$script:KnownChecksums = @{
    "timer_windows_amd64.zip" = "0c204022ecb58b8d5b37f2459c4797c8560eed0b3f43c6bf2bdd8a59d234e030"
    "timer_windows_arm64.zip" = "d99e04f0ee99144331330f862d0576e723b949ff16909d9f8b6e994cd7019f72"
}

# Resolve project root tools directory relative to this script
$targetDir = Join-Path $PSScriptRoot "bin"

$tempZip = Join-Path $env:TEMP "timer.zip"
$tempExtractDir = Join-Path $env:TEMP "timer_extracted"

# Force TLS 1.2 for secure connections on Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Create target directory if it does not exist
if (-not (Test-Path -Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

try {
    Write-Host "Resolving download URL for timer $tag..."

    $downloadUrl = $null
    $assetFileName = $null
    $headers = @{ "User-Agent" = "PowerShell-ps-sablier" }

    # Attempt to dynamically resolve asset download URL via GitHub API
    try {
        $apiUrl = "https://api.github.com/repos/$repo/releases/tags/$tag"
        $releaseData = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing
        $asset = $releaseData.assets | Where-Object {
            $_.name -match "windows" -and ($_.name -match "x86_64" -or $_.name -match "amd64") -and $_.name -match "\.zip$"
        } | Select-Object -First 1

        if ($asset) {
            $downloadUrl = $asset.browser_download_url
            $assetFileName = $asset.name
        }
    } catch {
        # Fallback to direct URL formats if API rate limit is exceeded
        Write-Host "GitHub API lookup failed or rate-limited. Falling back to direct URL..." -ForegroundColor Yellow
    }

    # If API resolution failed, try candidate direct release URLs
    if (-not $downloadUrl) {
        $candidateUrls = @(
            "https://github.com/$repo/releases/download/$tag/timer_windows_amd64.zip",
            "https://github.com/$repo/releases/download/$tag/timer_${version}_windows_amd64.zip",
            "https://github.com/$repo/releases/download/$tag/timer_${version}_Windows_x86_64.zip",
            "https://github.com/$repo/releases/download/$tag/timer_Windows_x86_64.zip"
        )

        foreach ($url in $candidateUrls) {
            try {
                $testReq = [System.Net.WebRequest]::Create($url)
                $testReq.Method = "HEAD"
                $testReq.UserAgent = "PowerShell"
                $res = $testReq.GetResponse()
                if ($res.StatusCode -eq 200) {
                    $downloadUrl = $url
                    $assetFileName = [System.IO.Path]::GetFileName($url)
                    $res.Close()
                    break
                }
                $res.Close()
            } catch {
                # Try next candidate URL
            }
        }
    }

    if (-not $downloadUrl) {
        throw "Could not determine a valid download URL for timer $tag."
    }

    # Download release archive
    Write-Host "Downloading from $downloadUrl..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -Headers $headers -UseBasicParsing

    # Verify cryptographic integrity (SHA256 checksum)
    Write-Host "Verifying archive integrity (SHA256)..."
    $calculatedHash = (Get-FileHash -LiteralPath $tempZip -Algorithm SHA256).Hash.ToLowerInvariant()

    # Match against known checksums based on resolved asset name or standard amd64 zip
    $expectedHash = $null
    if ($assetFileName -and $script:KnownChecksums.ContainsKey($assetFileName)) {
        $expectedHash = $script:KnownChecksums[$assetFileName]
    } else {
        # Default fallback for Windows AMD64 binary
        $expectedHash = $script:KnownChecksums["timer_windows_amd64.zip"]
    }

    if ($calculatedHash -ine $expectedHash) {
        throw "Security Error: Hash mismatch for '$tempZip'. Expected: $expectedHash, Actual: $calculatedHash"
    }

    Show-SuccessMessage "SHA256 checksum successfully verified ($calculatedHash)."

    # Extract the archive
    Write-Host "Extracting archive..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtractDir -Force

    # Locate timer.exe inside extracted files
    $exeFile = Get-ChildItem -Path $tempExtractDir -Filter "timer.exe" -Recurse -File | Select-Object -First 1

    if ($exeFile) {
        # Move executable to destination directory
        Move-Item -Path $exeFile.FullName -Destination (Join-Path $targetDir "timer.exe") -Force
        Write-Host "Success: 'timer.exe' has been placed in '$targetDir'." -ForegroundColor Green
    } else {
        throw "Could not find 'timer.exe' inside the downloaded archive."
    }
}
catch {
    Write-Error "Failed to install timer: $_"
}
finally {
    # Cleanup temporary files
    if (Test-Path -Path $tempZip) {
        Remove-Item -Path $tempZip -Force
    }
    if (Test-Path -Path $tempExtractDir) {
        Remove-Item -Path $tempExtractDir -Recurse -Force
    }
}

# Add binary directory to PATH for the current session instance if not already present
Initialize-ProjectEnvironment

# Verify timer binary availability and execution
try {
    timer --version
    Test-Timer
}
catch {
    Show-ErrorMessage "Failed to verify 'timer' binary in PATH: $_"
    exit 1
}