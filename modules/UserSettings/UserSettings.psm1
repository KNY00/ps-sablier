# Module-scoped configuration path
$script:ConfigDir  = Join-Path $env:LOCALAPPDATA "ps-sablier"
$script:ConfigFile = Join-Path $script:ConfigDir "settings.json"

# Default configuration template
$script:DefaultSettings = [ordered]@{
    SoundFilePath    = $false
    SkipIntroduction = $false
}

function Get-UserSetting {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    process {
        # Check if settings file exists; if not, return default template
        if (-not (Test-Path -LiteralPath $script:ConfigFile)) {
            [PSCustomObject]$script:DefaultSettings
            return
        }

        try {
            $rawContent = Get-Content -LiteralPath $script:ConfigFile -Raw -ErrorAction Stop
            $loadedSettings = $rawContent | ConvertFrom-Json -ErrorAction Stop

            # Ensure backward compatibility for missing properties
            if (-not ($loadedSettings.PSObject.Properties.Name -contains "SoundFilePath")) {
                $loadedSettings | Add-Member -MemberType NoteProperty -Name "SoundFilePath" -Value $script:DefaultSettings.SoundFilePath
            }
            if (-not ($loadedSettings.PSObject.Properties.Name -contains "SkipIntroduction")) {
                $loadedSettings | Add-Member -MemberType NoteProperty -Name "SkipIntroduction" -Value $script:DefaultSettings.SkipIntroduction
            }

            $loadedSettings
        }
        catch {
            Write-Error "Failed to read or parse configuration file at '$script:ConfigFile': $_"
            [PSCustomObject]$script:DefaultSettings
        }
    }
}

<#
.SYNOPSIS
    Retrieves the configured sound file path from user settings.

.DESCRIPTION
    Loads the user settings and extracts the SoundFilePath property.
    Returns the sound file path string or $false if sound alert is disabled / unset.
#>
function Get-UserSoundPath {
    [CmdletBinding()]
    param()

    process {
        # Retrieve active user configuration
        $settings = Get-UserSetting
        $settings.SoundFilePath
    }
}

<#
.SYNOPSIS
    Retrieves whether the startup introduction animation should be skipped.

.OUTPUTS
    [bool] True if intro animation is skipped, false otherwise.
#>
function Get-UserSkipIntro {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    process {
        $settings = Get-UserSetting
        [bool]$settings.SkipIntroduction
    }
}

function Set-UserSetting {
    [CmdletBinding()]
    param(
        # Validate that SoundFilePath is either a string or boolean $false
        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_)) {
                return $true
            }
            if ($_ -is [bool] -and $_ -eq $false) {
                return $true
            }
            throw "SoundFilePath must be a non-empty string or `$false."
        })]
        [object]$SoundFilePath,

        # Flag to toggle skipping the startup introduction animation
        [Parameter(Mandatory = $false)]
        [Nullable[bool]]$SkipIntroduction
    )

    process {
        # Ensure the target directory exists
        if (-not (Test-Path -LiteralPath $script:ConfigDir)) {
            New-Item -Path $script:ConfigDir -ItemType Directory -Force | Out-Null
        }

        # Load existing settings or start fresh
        $current = Get-UserSetting

        # Update the properties preserving existing values when parameters are omitted
        $targetSound = if ($PSBoundParameters.ContainsKey('SoundFilePath')) {
            $SoundFilePath
        } else {
            $current.SoundFilePath
        }

        $targetSkipIntro = if ($PSBoundParameters.ContainsKey('SkipIntroduction')) {
            [bool]$SkipIntroduction
        } elseif ($current.PSObject.Properties.Name -contains "SkipIntroduction") {
            [bool]$current.SkipIntroduction
        } else {
            $script:DefaultSettings.SkipIntroduction
        }

        $settingsObject = [ordered]@{
            SoundFilePath    = $targetSound
            SkipIntroduction = $targetSkipIntro
        }

        # Preserve any extra properties that might already exist in the file
        foreach ($prop in $current.PSObject.Properties) {
            if ($prop.Name -notin @("SoundFilePath", "SkipIntroduction")) {
                $settingsObject[$prop.Name] = $prop.Value
            }
        }

        try {
            # Convert object to JSON and persist to disk
            $settingsObject | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $script:ConfigFile -Encoding utf8 -ErrorAction Stop
            Write-Verbose "Settings successfully saved to '$script:ConfigFile'."
        }
        catch {
            Write-Error "Failed to save configuration file: $_"
        }
    }
}

Export-ModuleMember -Function Get-UserSetting, Get-UserSoundPath, Get-UserSkipIntro, Set-UserSetting