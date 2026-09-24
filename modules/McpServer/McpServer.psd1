@{
    RootModule           = 'McpServer.psm1'
    ModuleVersion        = '1.0.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID                 = 'b3d3957a-9c71-4649-8e2b-f89a94160eb8'
    Author               = 'kny00'
    CompanyName          = 'ps-sablier'
    Copyright            = '(c) 2026. All rights reserved.'
    Description          = 'Model Context Protocol (MCP) Server module for Sablier.'
    PowerShellVersion    = '5.1'
    
    # Declare the domain dependencies to ensure they are loaded
    RequiredModules      = @('TaskController', 'SessionController')
    FunctionsToExport    = @('Start-McpServerLoop', 'Get-McpToolsList', 'Invoke-McpToolCall')
}