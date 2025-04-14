# LogOff Disconnected Users

A PowerShell script to automatically log off disconnected user sessions while respecting a configurable whitelist of users that should not be logged off.

## Description

This script was designed to help manage user sessions on Windows systems by automatically logging off users who have been disconnected for a specified period of time. It includes a whitelist feature that allows administrators to exempt certain users from being automatically logged off.

### Key Features

- Log off users who have been disconnected for longer than a configurable threshold
- Maintain a whitelist of users who should never be automatically logged off
- Comprehensive logging of all actions
- Easy to set up as a scheduled task
- Configurable via a simple JSON file

## Requirements

- Windows operating system
- PowerShell 5.1 or higher
- Administrator privileges
- Access to query user sessions and log off users

## Installation

1. Clone or download this repository to your preferred location (e.g., `L:\Technology\Helpdesk\Helpdesk Scipts\LogOffDisconnectedUsers`)

2. Ensure the script and config file are in the same directory:
   - `LogOffDisconnectedUsers.ps1` (main script)
   - `config.json` (configuration file)

3. Make sure the directory structure is correct:
   ```
   LogOffDisconnectedUsers/
   ├── LogOffDisconnectedUsers.ps1
   ├── config.json
   └── logs/  (will be created automatically)
   ```

## Configuration

The script uses a JSON configuration file (`config.json`) that should be in the same directory as the script. Here's an example configuration:

```json
{
    "WhitelistedUsers": [
        "admin",
        "serviceaccount",
        "masonherbel"
    ],
    "DisconnectThresholdMinutes": 60,
    "LogFilePath": "L:\\Technology\\Helpdesk\\Helpdesk Scipts\\LogOffDisconnectedUsers\\logs\\LogOffDisconnected.log"
}
```

### Configuration Options

- **WhitelistedUsers**: Array of usernames that should not be logged off automatically
- **DisconnectThresholdMinutes**: Time (in minutes) a user can be disconnected before being logged off
- **LogFilePath**: Full path to the log file (will be created if it doesn't exist)

### How to Determine the Correct Username Format

To ensure you're using the correct username format in the whitelist, run the script with the `-ShowUsernames` parameter:

```powershell
.\LogOffDisconnectedUsers.ps1 -ShowUsernames
```

This will display all currently logged-in users in the exact format needed for the whitelist. Generally, usernames should be added exactly as they appear in the Windows `quser` command output.

## Usage

### Manual Execution

To run the script manually:

```powershell
.\LogOffDisconnectedUsers.ps1
```

To view the current username format for the whitelist:

```powershell
.\LogOffDisconnectedUsers.ps1 -ShowUsernames
```

### Setting Up as a Scheduled Task

1. Open Task Scheduler (taskschd.msc)
2. Create a new task with these settings:
   - Run with highest privileges: Yes
   - Configure for: Windows Server or Windows 10/11
   - Trigger: Daily or at your preferred schedule
   - Action: Start a program
     * Program/script: `powershell.exe`
     * Arguments: `-ExecutionPolicy Bypass -File "L:\path\to\LogOffDisconnectedUsers.ps1"`
   - Settings:
     * Allow task to be run on demand: Yes
     * Run task as soon as possible after a scheduled start is missed: Yes
     * If the task fails, restart every: 5 minutes
     * Attempt to restart up to: 3 times

## Logging

The script logs all actions to the specified log file, including:
- Script start and end times
- Configuration information
- Users who were disconnected and logged off
- Users who were spared due to being on the whitelist
- Any errors encountered

Example log entries:
```
[2025-04-14 15:30:00] [INFO] Script started
[2025-04-14 15:30:00] [INFO] Configuration loaded successfully
[2025-04-14 15:30:01] [INFO] Found 5 user sessions
[2025-04-14 15:30:01] [INFO] User admin is disconnected (Duration: 02:30:00) but whitelisted - skipping
[2025-04-14 15:30:02] [INFO] Logging off user jsmith (Session ID: 3, Duration: 01:15:30)
[2025-04-14 15:30:02] [INFO] User jsmith has been logged off successfully
[2025-04-14 15:30:03] [INFO] Script completed successfully
```

## Troubleshooting

If the script isn't working as expected:

1. Check the log file for error messages
2. Ensure the script is running with administrator privileges
3. Verify the whitelist contains the correct usernames
4. Make sure the log directory exists and is writable

## Notes

- The script requires administrator privileges to query sessions and log off users
- Users in the whitelist will never be logged off by this script
- The script will only log off users in the "Disconnected" state
- Modify the disconnect threshold in config.json to change how long users can remain disconnected

