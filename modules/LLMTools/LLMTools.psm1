Import-Module SecretKeyService -ErrorAction SilentlyContinue

function Get-ResolvedApiKey {
    [CmdletBinding()]
    param([string]$ProviderKeyName, [string]$EnvVarValue)

    # 1. Environment variable
    if (-not [string]::IsNullOrEmpty($EnvVarValue)) {
        return $EnvVarValue
    }

    # 2. SecretStore Vault
    if (Get-Command -Name "Get-ApiKeySecret" -ErrorAction SilentlyContinue) {
        $secret = Get-ApiKeySecret -Name $ProviderKeyName -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrEmpty($secret)) {
            return $secret
        }
    }

    return $null
}

# In-memory dictionary containing known endpoint configurations and cached keys
$script:Providers = @{
    'GoogleAI' = @{
        BaseUrl      = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
        AuthType     = 'Bearer'
        DefaultModel = 'gemma-4-31b-it'
        ApiKey       = (Get-ResolvedApiKey -ProviderKeyName 'GEMINI_API_KEY' -EnvVarValue $env:GEMINI_API_KEY)
    }
    'OpenAI'   = @{
        BaseUrl      = 'https://api.openai.com/v1/chat/completions'
        AuthType     = 'Bearer'
        DefaultModel = 'gpt-4o-mini'
        ApiKey       = (Get-ResolvedApiKey -ProviderKeyName 'OPENAI_API_KEY' -EnvVarValue $env:OPENAI_API_KEY)
    }
    'Groq'     = @{
        BaseUrl      = 'https://api.groq.com/openai/v1/chat/completions'
        AuthType     = 'Bearer'
        DefaultModel = 'llama-3.3-70b-versatile'
        ApiKey       = $env:GROQ_API_KEY
    }
    'Ollama'   = @{
        # Default local endpoint for Ollama
        BaseUrl      = 'http://localhost:11434/v1/chat/completions'
        AuthType     = 'None'
        DefaultModel = 'gemma4'
        ApiKey       = $null
    }
    'Mistral'  = @{
        BaseUrl      = 'https://api.mistral.ai/v1/chat/completions'
        AuthType     = 'Bearer'
        DefaultModel = 'mistral-large-latest'
        ApiKey       = $env:MISTRAL_API_KEY
    }
}

function Get-LLMProviders {
    <#
    .SYNOPSIS
        Lists currently configured provider templates.
    #>
    [CmdletBinding()]
    param()

    $script:Providers.GetEnumerator() | Select-Object `
        @{Name = 'Provider'; Expression = { $_.Key } },
        @{Name = 'DefaultModel'; Expression = { $_.Value.DefaultModel } },
        @{Name = 'BaseUrl'; Expression = { $_.Value.BaseUrl } },
        @{Name = 'HasKeyConfigured'; Expression = { -not [string]::IsNullOrEmpty($_.Value.ApiKey) } }
}

function Set-LLMProvider {
    <#
    .SYNOPSIS
        Configures an API key or custom endpoint for an existing or custom provider.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Provider,

        [Parameter(Mandatory = $false)]
        [string]$ApiKey,

        [Parameter(Mandatory = $false)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $false)]
        [string]$DefaultModel
    )

    # Initialize provider entry if not present
    if (-not $script:Providers.ContainsKey($Provider)) {
        $script:Providers[$Provider] = @{
            BaseUrl      = $BaseUrl
            AuthType     = 'Bearer'
            DefaultModel = $DefaultModel
            ApiKey       = $ApiKey
        }
        Write-Verbose "Registered new provider: $Provider"
        return
    }

    # Update provider fields
    if ($ApiKey)       { $script:Providers[$Provider].ApiKey = $ApiKey }
    if ($BaseUrl)      { $script:Providers[$Provider].BaseUrl = $BaseUrl }
    if ($DefaultModel) { $script:Providers[$Provider].DefaultModel = $DefaultModel }

    Write-Verbose "Updated provider: $Provider"
}

function Remove-ThoughtTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text
    )

    process {
        # (?s) enables Singleline mode so '.' matches newline characters (\n)
        # .*? performs a non-greedy match to handle multiple blocks correctly
        $pattern = '(?s)<thought>.*?</thought>'

        return ($Text -replace $pattern, '')
    }
}

<#
.SYNOPSIS
    Sends a chat completion request to the chosen LLM provider.
#>
<#
.SYNOPSIS
    Sends a chat completion request to the chosen LLM provider.
#>
function Invoke-LLM {
    [CmdletBinding()]
    param(
        # Made optional so we can recursively call the LLM using only the History
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string]$SystemPrompt,

        # Allow both hashtables and PSCustomObjects in History
        [Parameter(Mandatory = $false)]
        [object[]]$History = @(),

        # Added support for LLM Tools
        [Parameter(Mandatory = $false)]
        [array]$Tools,

        [Parameter(Mandatory = $false)]
        [string]$Provider = 'GoogleAI',

        [Parameter(Mandatory = $false)]
        [string]$Model,

        [Parameter(Mandatory = $false)]
        [string]$ApiKey,

        [Parameter(Mandatory = $false)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.0, 2.0)]
        [double]$Temperature = 0.7,

        [Parameter(Mandatory = $false)]
        [int]$MaxTokens = 2048,

        [Parameter(Mandatory = $false)]
        [switch]$RawResponse
    )

    process {
        # Determine provider configuration
        $config = if ($script:Providers.ContainsKey($Provider)) {
            $script:Providers[$Provider]
        } else {
            $null
        }

        # Resolve endpoint URL
        $targetUrl = if ($BaseUrl) {
            $BaseUrl
        } elseif ($config -and $config.BaseUrl) {
            $config.BaseUrl
        } else {
            throw "Base URL not defined for provider '$Provider'. Provide -BaseUrl or run Set-LLMProvider."
        }

        # Resolve target model name
        $selectedModel = if ($Model) {
            $Model
        } elseif ($config -and $config.DefaultModel) {
            $config.DefaultModel
        } else {
            throw "No model specified. Please specify -Model."
        }

        # Resolve API Key
        $resolvedKey = if ($ApiKey) {
            $ApiKey
        } elseif ($config -and $config.ApiKey) {
            $config.ApiKey
        } else {
            $null
        }

        # Prepare HTTP headers
        $headers = @{
            'Content-Type' = 'application/json; charset=utf-8'
        }

        if (-not [string]::IsNullOrEmpty($resolvedKey)) {
            $headers['Authorization'] = "Bearer $resolvedKey"
        }

        # Construct message array as generic objects
        $messages = [System.Collections.Generic.List[object]]::new()

        if (-not [string]::IsNullOrWhiteSpace($SystemPrompt)) {
            $messages.Add(@{ role = 'system'; content = $SystemPrompt })
        }

        # Inject conversation history before the new prompt
        if ($null -ne $History -and $History.Count -gt 0) {
            foreach ($msg in $History) {
                $messages.Add($msg)
            }
        }

        # Only append the Prompt if it contains text
        if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
            $messages.Add(@{ role = 'user'; content = $Prompt })
        }

        # Create OpenAI-compatible JSON payload
        $bodyObject = @{
            model       = $selectedModel
            messages    = $messages
            temperature = $Temperature
            max_tokens  = $MaxTokens
        }

        # Inject tools into payload if provided
        if ($null -ne $Tools -and $Tools.Count -gt 0) {
            $bodyObject.tools = $Tools
        }

        # Convert the payload to a JSON string
        $jsonPayload = $bodyObject | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $targetUrl `
                                          -Method Post `
                                          -Headers $headers `
                                          -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonPayload))

            if ($RawResponse) {
                return $response
            }

            if ($response.choices -and $response.choices.Count -gt 0) {
                $sanitized = Remove-ThoughtTags $response.choices[0].message.content
                return $sanitized
            }

            return $response
        }
        catch {
            Write-Error "LLM API request failed: $_"
            if ($_.Exception.Response) {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    Write-Error ("Response Body: " + $reader.ReadToEnd())
                }
            }
            throw $_
        }
    }
}

Export-ModuleMember -Function Invoke-LLM, Set-LLMProvider, Get-LLMProviders