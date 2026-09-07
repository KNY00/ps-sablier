# Shared functions for downloading and extracting archives

function Ensure-TargetDirectory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Validate or create the target directory
    if (-not (Test-Path -Path $Path)) {
        Write-Verbose "Target directory does not exist. Creating: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Download-AndExtractArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Ensure-TargetDirectory -Path $DestinationPath

    # Create a temporary file path for the archive
    $tempZipFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".zip")

    try {
        Write-Verbose "Downloading SQLite from: $Url"
        
        # Download archive using Invoke-WebRequest with basic parsing for compatibility
        Invoke-WebRequest -Uri $Url -OutFile $tempZipFile -UseBasicParsing

        Write-Verbose "Extracting archive to: $DestinationPath"
        # Expand ZIP archive, overwriting existing files
        Expand-Archive -Path $tempZipFile -DestinationPath $DestinationPath -Force

        Write-Host "SQLite successfully extracted to: $DestinationPath" -ForegroundColor Green
    }
    catch {
        throw "Failed to download or extract SQLite: $($_.Exception.Message)"
    }
    finally {
        # Clean up temporary ZIP archive
        if (Test-Path -Path $tempZipFile) {
            Remove-Item -Path $tempZipFile -Force -ErrorAction SilentlyContinue
        }
    }
}