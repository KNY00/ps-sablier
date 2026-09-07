# TaskController.psd1
@{
RootModule        = 'TaskController.psm1'
ModuleVersion     = '1.0.0'
PowerShellVersion = '5.1'
GUID              = 'a1b2c3d4-e5f6-4a5b-8c7d-9e0f1a2b3c4d'
Author            = 'kny00'
FunctionsToExport = @(
    'Get-TaskSessionItems',
    'New-TaskItem',
    'Get-TaskItem',
    'Undo-TaskItemCompletion', `
    'Complete-TaskItem', `
    'Set-TaskItem',
    'Remove-TaskItem'
)
CmdletsToExport   = @()
VariablesToExport = @()
AliasesToExport   = @()
RequiredModules = @('SqliteUtils', 'UiNotificationUtils')
}