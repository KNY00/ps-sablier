<#
.SYNOPSIS
    Interactive AI Agent chat interface with autonomous Tool Calling.

.DESCRIPTION
    Provides a continuous chat loop allowing the user to ask questions.
    If the model calls a tool, the agent executes it locally and feeds the 
    result back to the model autonomously without prompting the user.
#>
[CmdletBinding()]
param ()

# Import-Module CheckDependencies -ErrorAction Stop
# Import-Module MenuUtils -ErrorAction Stop
# Import-Module UiNotificationUtils -ErrorAction Stop
# Import-Module UserSettings -ErrorAction Stop
# Import-Module SecretKeyService -ErrorAction SilentlyContinue
# Import-Module LLMTools -ErrorAction Stop
# Import-Module McpServer -ErrorAction Stop


Test-ProjectPrerequisite

$geminiApiKey = Get-ApiKeySecret -Name "GEMINI_API_KEY" -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace($geminiApiKey)) {
    $geminiApiKey = $env:GEMINI_API_KEY
}

if ([string]::IsNullOrWhiteSpace($geminiApiKey)) {
    Show-ErrorMessage "No Gemini API key found. Please configure it in Settings > Configure Gemini API Key."
    Pause
    return
}

$configuredModel = Get-UserLlmModelName
if ([string]::IsNullOrWhiteSpace($configuredModel)) {
    $configuredModel = "gemini-3.5-flash-lite"
}

$systemPrompt = "You are a helpful AI assistant for the ps-sablier time tracking and task management application. Answer concisely and assist the user."

# Dynamically adapt MCP tools definition into OpenAI tool schemas
$mcpToolsData = Get-McpToolsList
$agentTools = @(
    foreach ($tool in $mcpToolsData.tools) {
        @{
            type = "function"
            function = @{
                name        = $tool.name
                description = $tool.description
                parameters  = $tool.inputSchema
            }
        }
    }
)

# Initialize conversation history collection as generic object list
$chatHistory = [System.Collections.Generic.List[object]]::new()

Clear-Host
Write-Host "=== Ask Agent (Model: $configuredModel) ===" -ForegroundColor Cyan
Write-Host "Type your question below, or type 'exit' to return to the main menu.`n" -ForegroundColor Gray

while ($true) {
    # 1. User Input Phase
    $userInput = Read-ConsoleLineOrEscape -Prompt "You: "
    
    if ($null -eq $userInput -or $userInput.Trim().ToLower() -in @('exit', 'quit')) {
        Write-Host "`nReturning to main menu..." -ForegroundColor Yellow
        break
    }

    if ([string]::IsNullOrWhiteSpace($userInput)) {
        continue
    }

    # Append user prompt to history
    $chatHistory.Add(@{ role = 'user'; content = $userInput })
    
    # 2. Autonomous Agent Execution Loop
    $isResolvingTools = $true
    
    while ($isResolvingTools) {
        Write-Host "Agent is thinking..." -ForegroundColor DarkGray
        
        try {
            # Execute LLM and request raw response to catch tool_calls
            $response = Invoke-LLM -SystemPrompt $systemPrompt `
                                   -History $chatHistory `
                                   -Provider "GoogleAI" `
                                   -ApiKey $geminiApiKey `
                                   -Model $configuredModel `
                                   -Tools $agentTools `
                                   -RawResponse
            
            $message = $response.choices[0].message
            
            # Print content to the user if the model generated a message alongside the tool call
            if (-not [string]::IsNullOrWhiteSpace($message.content)) {
                Write-Host "`nAgent:" -ForegroundColor Green
                Write-Host $message.content
            }
            
            # Check if a tool call was triggered
            if ($null -ne $message.tool_calls -and $message.tool_calls.Count -gt 0) {
                # Preserve the assistant message containing tool_calls in history
                $chatHistory.Add($message)
                
                foreach ($tc in $message.tool_calls) {
                    Write-Host "Executing tool: $($tc.function.name)..." -ForegroundColor Cyan
                    
                    $proposedArgs = $tc.function.arguments | ConvertFrom-Json
                    
                    # Execute tool via shared dispatch logic
                    try {
                        $toolResult = Invoke-McpToolCall -Name $tc.function.name -Arguments $proposedArgs
                    }
                    catch {
                        $toolResult = (@{ error =$_.Exception.Message } | ConvertTo-Json -Compress)
                    }
                    
                    # Push tool execution result back into history
                    $chatHistory.Add(@{
                        role         = "tool"
                        tool_call_id = $tc.id
                        name         = $tc.function.name
                        content      = $toolResult
                    })
                }
            } else {
                # Log regular assistant response into history
                $chatHistory.Add(@{ role = 'assistant'; content = $message.content })
                
                Write-Host "`n----------------------------------------`n" -ForegroundColor DarkGray

                # Break the autonomous loop and wait for user's next input
                $isResolvingTools = $false
            }
        } 
        catch {
            Show-ErrorMessage "Failed to communicate with the LLM: $_"
            $isResolvingTools = $false
        }
    }
}