# Import the SecretStore extension module
Import-Module Microsoft.PowerShell.SecretStore -ErrorAction Stop

# Reset the vault store
Reset-SecretStore -Password $null -Force

# Configure passwordless and non-interactive mode
Set-SecretStoreConfiguration -Authentication None -Interaction None -Confirm:$false