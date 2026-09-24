@{
    # Script module or binary module file associated with this manifest
    RootModule           = 'LLMTools.psm1'
    ModuleVersion        = '1.0.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID                 = 'b9e71f40-77a8-4ce6-a704-58e1c6b12f71'
    Author               = 'Your Name'
    Description          = 'Multi-provider PowerShell module to query Google AI Studio, OpenAI, Groq, Ollama, and other LLMs.'
    FunctionsToExport    = @('Invoke-LLM', 'Set-LLMProvider', 'Get-LLMProviders')
}