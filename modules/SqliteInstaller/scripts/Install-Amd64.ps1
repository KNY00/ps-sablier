[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

# Import shared helper utilities
$sharedScript = Join-Path -Path $PSScriptRoot -ChildPath 'Shared.ps1'
. $sharedScript

# Official x64 Windows binary URL for SQLite CLI tools
$downloadUrl = 'https://www.sqlite.org/2024/sqlite-tools-win-x64-3460100.zip'

Write-Verbose "Starting SQLite x64 installation..."
Download-AndExtractArchive -Url $downloadUrl -DestinationPath $FilePath