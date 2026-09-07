<p align="center">
  <img src="assets/icon.png" alt="Project Icon" width="64" height="64" />
</p>

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=flat&logo=powershell&logoColor=white)

# ps-sablier

> An interactive command-line interface (CLI) application for time management and productivity tracking with local SQLite persistence.

<p align="center">
  <img src="assets/demo-start-tracking.gif" alt="Centered GIF">
</p>

## 📋 Overview

**ps-sablier** is a command-line tool built with PowerShell (compatible with Windows PowerShell 5.1 and PowerShell 7+). It allows you to track your time with minimal resource usage, running entirely within PowerShell. You can start untimed, open-ended tracking sessions or timed sessions, after which a Windows notification will alert you upon completion. All sessions can be saved to a local SQLite database and linked directly to tasks.

### Key Features:

- ⏱ **Session Timer & Free Tracking**: Configurable timer (e.g., `25m`, `1h`) with terminal visual progress bars (via the `timer` tool) or an open stopwatch with pause/resume support.
- 🔔 **Notifications & Sound Alerts**: Native Windows Toast notifications (WinRT) and customizable audio cues (`.wav`) at the end of each session.
- 📝 **Task Manager**: Create, update, toggle status (Pending / Completed), full-text search, and cascade deletion.
- 📊 **Session Manager**: Log past sessions manually, inspect recent history, and link tracked intervals to existing tasks.
- 💾 **Flexible SQLite Persistence**: Native support for the official `sqlite3` CLI or the `PSSQLite` PowerShell module.
- ⚙ **Custom User Settings**: Persisted local configuration stored in `$env:LOCALAPPDATA/ps-sablier/settings.json`.

## ⚙️ Prerequisites

- **Operating System**: Windows 10 / 11 or Windows Server (supported architectures: `AMD64` / `x86_64`).
- **PowerShell**: PowerShell 5.1 (Desktop) or PowerShell 7+.
- **Script Execution Policy**: Ensure PowerShell script execution is enabled for your current user session:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

> [!IMPORTANT]
>
> **Required Dependencies Before Use:**
> The application requires two external components to operate:
> * **An SQLite backend**: The `sqlite3.exe` CLI binary available in `PATH` or the `PSSQLite` PowerShell module.
> * **The Timer binary**: The `timer.exe` executable available in `PATH` or inside `tools/bin`.
> If these components are not manually installed, execute the included bootstrap script `.\bootstrap.ps1` to automatically download and configure them.

## 🚀 Installation

The project includes an automatic bootstrap script (`bootstrap.ps1`) that sets up all dependencies (downloads SQLite and timer binaries, initializes the database schema, and validates the environment).

1. **Clone or download the repository:**
```powershell
git clone https://github.com/KNY00/ps-sablier
cd ps-sablier
```


2. **Run the bootstrap script:**
```powershell
.\bootstrap.ps1
```


This script automatically handles:
* Downloading and configuring the **SQLite** CLI tool for your system architecture (into `tools/bin`).
* Downloading the **timer.exe** binary (v1.4.6 from *caarlos0/timer*).
* Initializing the local database (`assets/db.sqlite`) from the SQL schema (`src/Assets/schema.sql`).
* Verifying all prerequisites (`Test-ProjectPrerequisite`).


## 🎮 Usage

To launch the interactive CLI interface:

```powershell
.\Start.ps1
```

An interactive menu navigable with the arrow keys (`↑` / `↓`) and `Enter`:

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
