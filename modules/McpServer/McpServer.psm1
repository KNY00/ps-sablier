<#
.SYNOPSIS
    Core loop for the Stdio MCP (Model Context Protocol) Server.
#>

. (Join-Path $PSScriptRoot "ToolsList.ps1")

function Start-McpServerLoop {
    [CmdletBinding()]
    param ()

    # JSON-RPC listener loop over Standard Input (Stdio)
    while ($line = [Console]::ReadLine()) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        try {
            $request = $line | ConvertFrom-Json
            $response = @{ jsonrpc = "2.0"; id = $request.id }

            switch ($request.method) {
                "initialize" {
                    $response.result = @{
                        protocolVersion = "2024-11-05"
                        capabilities = @{ tools = @{} }
                        serverInfo = @{ name = "ps-sablier-mcp"; version = "1.1.0" }
                    }
                }
                "tools/list" {
                    $response.result = Get-McpToolsList
                }
                "tools/call" {
                    $requestArgs = $request.params.arguments
                    $resultContent = Invoke-McpToolCall -Name $request.params.name -Arguments $requestArgs
                    
                    # Return stringified result inside the content block
                    $response.result = @{ content = @(@{ type = "text"; text = $resultContent }) }
                }
            }
            
            # Send response back to the MCP client
            $response | ConvertTo-Json -Depth 10 -Compress | Write-Host
        }
        catch {
            # Construct and return an error payload
            $errorResponse = @{
                jsonrpc = "2.0"
                id = if ($null -ne $request -and $null -ne $request.id) { $request.id } else { $null }
                error = @{ code = -32603; message = $_.Exception.Message }
            }
            $errorResponse | ConvertTo-Json -Compress | Write-Host
        }
    }
}

Export-ModuleMember -Function Start-McpServerLoop, Get-McpToolsList, Invoke-McpToolCall