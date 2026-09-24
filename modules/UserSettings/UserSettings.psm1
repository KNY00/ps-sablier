# Module-scoped configuration path
$script:ConfigDir  = Join-Path $env:LOCALAPPDATA "ps-sablier"
$script:ConfigFile = Join-Path $script:ConfigDir "settings.json"

# Default configuration template
$script:DefaultSettings = [ordered]@{
    SoundFilePath    = $false
    SkipIntroduction = $false
    UseExternalTimer = $false
    LlmModelName     = "gemini-3.5-flash-lite"
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
            if (-not ($loadedSettings.PSObject.Properties.Name -contains "UseExternalTimer")) {
                $loadedSettings | Add-Member -MemberType NoteProperty -Name "UseExternalTimer" -Value $script:DefaultSettings.UseExternalTimer
            }
            if (-not ($loadedSettings.PSObject.Properties.Name -contains "LlmModelName")) {
                $loadedSettings | Add-Member -MemberType NoteProperty -Name "LlmModelName" -Value $script:DefaultSettings.LlmModelName
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
#>
function Get-UserSoundPath {
    [CmdletBinding()]
    param()

    process {
        $settings = Get-UserSetting
        $settings.SoundFilePath
    }
}

<#
.SYNOPSIS
    Retrieves whether the startup introduction animation should be skipped.
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

<#
.SYNOPSIS
    Retrieves whether the external timer tool should be used over the fallback timer.
#>
function Get-UserUseExternalTimer {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    process {
        $settings = Get-UserSetting
        [bool]$settings.UseExternalTimer
    }
}

<#
.SYNOPSIS
    Retrieves the configured LLM model name from user settings.
#>
function Get-UserLlmModelName {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    process {
        $settings = Get-UserSetting
        [string]$settings.LlmModelName
    }
}

function Set-UserSetting {
    [CmdletBinding()]
    param(
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

        [Parameter(Mandatory = $false)]
        [Nullable[bool]]$SkipIntroduction,

        [Parameter(Mandatory = $false)]
        [Nullable[bool]]$UseExternalTimer,

        [Parameter(Mandatory = $false)]
        [string]$LlmModelName
    )

    process {
        if (-not (Test-Path -LiteralPath $script:ConfigDir)) {
            New-Item -Path $script:ConfigDir -ItemType Directory -Force | Out-Null
        }

        $current = Get-UserSetting

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

        $targetExternalTimer = if ($PSBoundParameters.ContainsKey('UseExternalTimer')) {
            [bool]$UseExternalTimer
        } elseif ($current.PSObject.Properties.Name -contains "UseExternalTimer") {
            [bool]$current.UseExternalTimer
        } else {
            $script:DefaultSettings.UseExternalTimer
        }

        $targetModelName = if ($PSBoundParameters.ContainsKey('LlmModelName')) {
            $LlmModelName
        } elseif ($current.PSObject.Properties.Name -contains "LlmModelName") {
            [string]$current.LlmModelName
        } else {
            $script:DefaultSettings.LlmModelName
        }

        $settingsObject = [ordered]@{
            SoundFilePath    = $targetSound
            SkipIntroduction = $targetSkipIntro
            UseExternalTimer = $targetExternalTimer
            LlmModelName     = $targetModelName
        }

        foreach ($prop in $current.PSObject.Properties) {
            if ($prop.Name -notin @("SoundFilePath", "SkipIntroduction", "UseExternalTimer", "LlmModelName")) {
                $settingsObject[$prop.Name] = $prop.Value
            }
        }

        try {
            $settingsObject | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $script:ConfigFile -Encoding utf8 -ErrorAction Stop
            Write-Verbose "Settings successfully saved to '$script:ConfigFile'."
        }
        catch {
            Write-Error "Failed to save configuration file: $_"
        }
    }
}

Export-ModuleMember -Function `
    Get-UserSetting, `
    Get-UserSoundPath, `
    Get-UserSkipIntro, `
    Get-UserUseExternalTimer, `
    Get-UserLlmModelName, `
    Set-UserSetting