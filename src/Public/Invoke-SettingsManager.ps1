<#
.SYNOPSIS
    Interactive settings configuration menu.

.DESCRIPTION
    Displays active configuration settings and provides interactive prompts to modify
    or disable sound alert paths as well as toggle startup introduction animation.

.EXAMPLE
    .\Invoke-SettingsManager.ps1
#>

[CmdletBinding()]
param ()

Import-Module CheckDependencies -ErrorAction Stop
Import-Module MenuUtils -ErrorAction Stop
Import-Module UiNotificationUtils -ErrorAction Stop
Import-Module UserSettings -ErrorAction Stop

# Pre-flight dependency check
Test-ProjectPrerequisite

function Show-CurrentSettings {
    $settings = Get-UserSetting
    
    $soundDisplay = if ($settings.SoundFilePath -eq $false -or [string]::IsNullOrWhiteSpace($settings.SoundFilePath)) {
        "Disabled ($false)"
    } else {
        $settings.SoundFilePath
    }

    $skipIntroDisplay = if ($settings.SkipIntroduction) { "Enabled ($true)" } else { "Disabled ($false)" }

    Write-Host "`n=== Active Settings ===" -ForegroundColor Cyan
    Write-Host " Sound File Path   : $soundDisplay" -ForegroundColor Gray
    Write-Host " Skip Introduction : $skipIntroDisplay" -ForegroundColor Gray
    Write-Host ""
}

function Update-SoundFilePathWorkflow {
    $currentSettings = Get-UserSetting
    $currentValue = $currentSettings.SoundFilePath

    $displayCurrent = if ($currentValue -eq $false) { "Disabled ($false)" } else { "'$currentValue'" }
    Write-Host "`nCurrent SoundFilePath: $displayCurrent" -ForegroundColor Cyan

    $actionOptions = @(
        "Set Custom Audio Path",
        "Disable / Set to False",
        "Cancel"
    )

    $choice = Show-Menu -Title "Choose an action for SoundFilePath:" -Options $actionOptions

    switch ($choice) {
        "Set Custom Audio Path" {
            $inputPath = Read-Host "Enter absolute or relative path to sound file (.wav)"
            if ([string]::IsNullOrWhiteSpace($inputPath)) {
                Show-InfoMessage "No path entered. Operation cancelled."
                return
            }

            # Optional existence validation
            if (-not (Test-Path -Path $inputPath)) {
                Show-InfoMessage "File '$inputPath' does not currently exist."
                $proceed = Confirm-Action -Message "Do you still want to save this path?"
                if (-not $proceed) {
                    Write-Host "Operation aborted." -ForegroundColor Yellow
                    return
                }
            }

            Set-UserSetting -SoundFilePath $inputPath
            Show-SuccessMessage "SoundFilePath updated to '$inputPath'."
        }

        "Disable / Set to False" {
            Set-UserSetting -SoundFilePath $false
            Show-SuccessMessage "SoundFilePath disabled (set to `$false)."
        }

        "Cancel" {
            Write-Host "Update cancelled." -ForegroundColor Yellow
        }
    }
}

function Update-SkipIntroductionWorkflow {
    $currentSettings = Get-UserSetting
    $currentStatus = if ($currentSettings.SkipIntroduction) { "Enabled ($true)" } else { "Disabled ($false)" }
    Write-Host "`nCurrent Skip Introduction: $currentStatus" -ForegroundColor Cyan

    $options = @(
        "Enable Skip Intro (Do not show animation)",
        "Disable Skip Intro (Show animation)",
        "Cancel"
    )

    $choice = Show-Menu -Title "Choose an option for Skip Introduction:" -Options $options

    switch ($choice) {
        "Enable Skip Intro (Do not show animation)" {
            Set-UserSetting -SkipIntroduction $true
            Show-SuccessMessage "Skip Introduction set to `$true (animation skipped)."
        }
        "Disable Skip Intro (Show animation)" {
            Set-UserSetting -SkipIntroduction $false
            Show-SuccessMessage "Skip Introduction set to `$false (animation displayed)."
        }
        "Cancel" {
            Write-Host "Update cancelled." -ForegroundColor Yellow
        }
    }
}

function Show-SettingsMenu {
    $menuOptions = @(
        "View Current Settings",
        "Update SoundFilePath",
        "Disable Sound Alerts ($false)",
        "Configure Skip Introduction",
        "Exit"
    )

    while ($true) {
        Clear-Host
        $choice = Show-Menu -Title "=== Settings Manager ===" -Options $menuOptions

        # Exit and return to caller (Start.ps1) if Escape was pressed or Exit selected
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "Exit") {
            return
        }

        switch ($choice) {
            "View Current Settings" {
                Show-CurrentSettings
                Pause
            }

            "Update SoundFilePath" {
                Update-SoundFilePathWorkflow
                Pause
            }

            "Disable Sound Alerts ($false)" {
                Set-UserSetting -SoundFilePath $false
                Show-SuccessMessage "Sound alert disabled (set to `$false)."
                Pause
            }

            "Configure Skip Introduction" {
                Update-SkipIntroductionWorkflow
                Pause
            }

            "Exit" {
                return
            }
        }
    }
}

Show-SettingsMenu