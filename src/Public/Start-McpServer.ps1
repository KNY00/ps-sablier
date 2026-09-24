<#
.SYNOPSIS
    MCP (Model Context Protocol) Server via Stdio for ps-sablier.
.DESCRIPTION
    Entry point for the MCP server. Exposes session modification, 
    task creation, and linking capabilities to MCP-compatible LLMs 
    (Claude Desktop, Cursor, etc.).
#>
[CmdletBinding()]
param ()

# Resolve the root module path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ModulesDir = Join-Path $ProjectRoot "modules"

# Ensure the local modules directory is inside PSModulePath
$currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
if ($ModulesDir -notin $currentPaths) {
    $env:PSModulePath = "$ModulesDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
}

# Import the new MCP Server module (which will automatically load Task & Session controllers)
Import-Module McpServer -ErrorAction Stop

# Start the JSON-RPC Stdio listener
Start-McpServerLoop