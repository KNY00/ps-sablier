<div align="center">
  <img src="assets/icon.png" alt="Project Icon" width="64" height="64" />
</div>

# ps-sablier

![PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-%235391FE.svg?style=flat&logo=powershell&logoColor=white) ![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-%235391FE.svg?style=flat&logo=powershell&logoColor=white)


A lightweight, terminal-based focus timer and Pomodoro tracker written in PowerShell. It enables you to organize tasks, log work and break intervals, associate sessions with tasks, and receive desktop audio-visual notifications upon completion.

<div align="center">
  <img src="assets/demo-start-tracking.gif" alt="Demo Start Tracking" />
</div>

Powered by a feature-rich MCP server for seamless agent control
<div align="center">

  <img src="assets/demo-mcp.gif" alt="MCP server capabilities" />
</div>

### Key Features:

- ⏱ **Session Timer & Free Tracking**: Configurable timer (e.g., `25m`, `1h`) with terminal visual progress bars (via the `timer` tool) or an open stopwatch with pause/resume support.
- 🔔 **Notifications & Sound Alerts**: Native Windows Toast notifications (WinRT) and customizable audio cues (`.wav`) at the end of each session.
- 📝 **Task Manager**: Create, update, toggle status (Pending / Completed), full-text search, and cascade deletion.
- 📊 **Session Manager**: Log past sessions manually, inspect recent history, and link tracked intervals to existing tasks.
- 🤖 **ps-sablier** integrates a full ecosystem allowing local and Large Language Models (LLMs) to control the application end-to-end.

## Architecture & Requirements

### System Requirements
- **Operating System:** Windows (x64 or ARM64). *The `SQLiteLoader` module is strictly restricted to Windows for the native loading of `e_sqlite3.dll`.*
- **PowerShell:** Windows PowerShell 5.1 (Desktop) or PowerShell 7+ (Core).

### PowerShell Modules
The application uses the local secret manager to securely store your API keys. If these modules are missing, the startup script will attempt to install them automatically for the current user:
- `Microsoft.PowerShell.SecretManagement`
- `Microsoft.PowerShell.SecretStore`

### Optional Components
- **External Timer (`timer.exe`):** The application will offer to download the third-party `timer` executable (caarlos0/timer v1.4.6) for time display. **This component is 100% optional.** If you decline or if it is not found, a built-in native timer with a progress bar ("sand timer") will be used as a fallback.
- **LLM API Key (Google Gemini, OpenAI, Groq, Mistral, etc.):** Required only if you wish to use the AI Agent features (via `Invoke-SablierAgent.ps1` or session notes correction via `Invoke-SessionLLMCorrection`). You can configure your key (e.g., `GEMINI_API_KEY`) through the *Settings Manager* menu.


## Getting Started

### 1. Initialization (`bootstrap.ps1`)

Run the bootstrap script to register internal modules, initialize your SQLite database, and choose your timer preferences:

```powershell
# Run the initial environment setup
.\bootstrap.ps1
```

During bootstrap:

1. The script verifies that the embedded `.NET SQLite` assemblies are present and initializes the database with `src\Assets\schema.sql`.
2. The script checks for the external `timer.exe`. If not installed, it displays a security notice and prompts whether you wish to download it.
3. Choosing **No** configures the application to use the built-in ASCII sand timer (default).
4. Choosing **Yes** downloads the official binary, validates its SHA256 checksum against the trusted release manifest, and enables it in your configuration.

### 2. Launching the Application

Start the interactive console dashboard:

```powershell
# Launch the main interactive menu
.\Start.ps1
```

Navigate the menus using the **Up/Down Arrow** keys and press **Enter** to confirm your selection.

- **Start Tracking**
  - `session`: Start a countdown timer (default: 25m).
  - `free`: Launch an open stopwatch (`Space` to pause/resume, `Q` to stop/exit).
  - *Automatic desktop notification upon completion, followed by a prompt to link the session to a task.*
- **Task Manager**
  - View and filter tasks by status (`Pending`, `Completed`, `All`).
  - Add, edit, complete, or reopen tasks.
  - Inspect logged session history and percentage breakdowns.
- **Session Manager**
  - Manually record past sessions via an interactive date/time picker.
  - Review and edit previous logs.
- **Settings**
  - Inspect active configurations.
  - Set or disable custom notification sounds (`.wav`).
  - Toggle the startup intro animation.
- **Exit**
  - Quit the application.


## Configuration (`Settings`)

Configuration is stored in `%LOCALAPPDATA%\ps-sablier\settings.json`. You can inspect and modify settings directly from the **Settings** menu within `Start.ps1`:

* **Timer Progress Bar**:
* `Built-in Fallback (Sand Timer)` (*Default*): Self-contained, rendered entirely in ASCII within the terminal.
* `External Binary (timer.exe)`: Standalone compiled binary placed in `tools\bin`.


* **Sound File Path**: Path to a custom `.wav` sound file for notifications, or set to `$false` to fall back to system audio alerts.
* **Skip Introduction**: Toggle the startup ASCII hourglass animation on or off.

## AI Agent & LLM Setup

To enable full support for the interactive AI Agent (`Ask Agent`) and session analysis / note correction features, configure a Google AI Studio API key by doing this :

1. Launch the application:

```powershell
.\Start.ps1
```
2. Navigate to Settings > Configure Gemini API Key > Set / Update Gemini API Key.

3. Paste your Gemini API key (input will be masked). The key is stored securely in your local secret store (SecretStore).

## Running Tests

To run the test suite:

```powershell
# Execute the isolated test runner 7.x
pwsh -File .\Tests\Invoke-AllTests.ps1 -Output Detailed
```

> [!NOTE]
> **PowerShell & Pester Requirements**: The test suite currently requires **PowerShell 7+** (`pwsh`) and **Pester 6.x+**. Running tests under Windows PowerShell 5.1 is not supported yet.

The runner:

* Tests provided are meant to be executed with Pester 6.+ and Powershell 7.
* Creates an ephemeral SQLite test database via `TestHelper.ps1`.
* Executes tests without altering your production `assets\db.sqlite`.
* Safely closes connection handles and removes the temporary database upon completion.
