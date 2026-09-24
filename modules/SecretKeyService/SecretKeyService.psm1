<#
.SYNOPSIS
    Service managing API key persistence using SecretManagement and SecretStore.
#>

$script:DefaultVaultName = "LocalVault"

function Initialize-SecretVaultService {
    <#
    .SYNOPSIS
        Ensures SecretManagement and SecretStore modules are installed and registers LocalVault.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$VaultName = $script:DefaultVaultName
    )

    # Verify and install required modules if missing
    $requiredModules = @('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore')
    foreach ($moduleName in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            Write-Verbose "Installing module $moduleName..."
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
        }
        if (-not (Get-Module -Name $moduleName)) {
            Import-Module -Name $moduleName -ErrorAction Stop
        }
    }

    # Register local vault as default if not already registered
    $existingVault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
    if (-not $existingVault) {
        Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault -ErrorAction Stop
        Write-Verbose "Registered default secret vault: $VaultName"
    }

    # Configure store to run without interactive prompt hurdles for local app service usage
    Set-SecretStoreConfiguration -Authentication None -Interaction None -Confirm:$false -ErrorAction SilentlyContinue
}

function Set-ApiKeySecret {
    <#
    .SYNOPSIS
        Saves or updates an API key in the vault.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ApiKey,

        [Parameter(Mandatory = $false)]
        [string]$Vault = $script:DefaultVaultName
    )

    Initialize-SecretVaultService -VaultName $Vault

    # Store API key as a secure secret entry
    Set-Secret -Name $Name -Secret $ApiKey -Vault $Vault
    return $true
}

function Get-ApiKeySecret {
    <#
    .SYNOPSIS
        Retrieves a stored API key by name from the vault.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Vault = $script:DefaultVaultName
    )

    Initialize-SecretVaultService -VaultName $Vault

    $secret = Get-Secret -Name $Name -Vault $Vault -AsPlainText -ErrorAction SilentlyContinue
    return $secret
}

function Remove-ApiKeySecret {
    <#
    .SYNOPSIS
        Removes an API key secret from the vault.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Vault = $script:DefaultVaultName
    )

    Initialize-SecretVaultService -VaultName $Vault

    Unregister-Secret -Name $Name -Vault $Vault -ErrorAction SilentlyContinue
    return $true
}

Export-ModuleMember -Function Initialize-SecretVaultService, Set-ApiKeySecret, Get-ApiKeySecret, Remove-ApiKeySecret