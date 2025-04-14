# LogOff Disconnected Users

A PowerShell script to automatically log off disconnected user sessions while respecting a configurable whitelist of users that should not be logged off.

## Description

This script was designed to help manage user sessions on Windows systems by automatically logging off users who have been disconnected for a specified period of time. It includes a whitelist feature that allows administrators to exempt certain users from being automatically logged off.

### Key Features

- Log off users who have been disconnected for longer than a configurable threshold
- Maintain a whitelist of users who should never be automatically logged off
- Comprehensive logging of all actions with detailed session information
- Detailed session reporting with statistics and summaries
- Easy to set up as a scheduled task
- Configurable via a simple JSON file

## Requirements

- Windows operating system
- PowerShell 5.1 or higher
- Administrator privileges
- Access to query user sessions and log off users

## Installation

1. Clone or download this repository to your preferred location (e.g., `C:\Scripts\LogOffDisconnectedUsers`)

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
    "LogFilePath": ".\\logs\\LogOffDisconnected.log"
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
     * Arguments: `-ExecutionPolicy Bypass -File "C:\path\to\LogOffDisconnectedUsers.ps1"`
   - Settings:
     * Allow task to be run on demand: Yes
     * Run task as soon as possible after a scheduled start is missed: Yes
     * If the task fails, restart every: 5 minutes
     * Attempt to restart up to: 3 times

## Logging
## Logging

The script provides detailed logging of all actions to the specified log file, including:

### Session Information
- Complete details of all sessions (active, disconnected, and other states)
- Session duration and idle time for each user
- Logon time information for each session
- Whitelist status tracking for all users

### Action Logging
- Script start and end times
- Configuration information
- Detailed information about disconnected users
- Actions taken for each session (logged off, skipped due to whitelist, etc.)
- Reasons for decisions (e.g., under threshold, whitelisted)
- Any errors encountered

### Session Statistics
- Summary of all detected sessions
- Counts of active vs. disconnected sessions
- Number of users logged off
- Number of whitelisted users skipped
- Number of users under the disconnect threshold
- Overall session processing summary

Example log entries:
```
[2025-04-14 15:30:00] [INFO] Script started
[2025-04-14 15:30:00] [INFO] Configuration loaded successfully
[2025-04-14 15:30:01] [INFO] Found 5 user sessions
[2025-04-14 15:30:01] [INFO] Session details summary:
[2025-04-14 15:30:01] [INFO]   • User: admin, State: Disc, Session ID: 2, WHITELISTED
[2025-04-14 15:30:01] [INFO]   • User: jsmith, State: Disc, Session ID: 3, not whitelisted
[2025-04-14 15:30:01] [INFO]   • User: masonherbel, State: Active, Session ID: 1, WHITELISTED
[2025-04-14 15:30:01] [INFO]   • User: testuser, State: Disc, Session ID: 4, not whitelisted
[2025-04-14 15:30:01] [INFO]   • User: operator, State: Active, Session ID: 5, not whitelisted
[2025-04-14 15:30:01] [INFO] User masonherbel is active (Session ID: 1, Logon Time: 2025-04-14 08:15:30, Duration: 07:14:31)
[2025-04-14 15:30:01] [INFO] User operator is active (Session ID: 5, Logon Time: 2025-04-14 14:45:12, Duration: 00:44:49)
[2025-04-14 15:30:01] [INFO] User admin is disconnected (Session ID: 2, Logon Time: 2025-04-14 09:30:00, Duration: 06:00:01)
[2025-04-14 15:30:01] [INFO]   → User admin is whitelisted - skipping
[2025-04-14 15:30:01] [INFO] User jsmith is disconnected (Session ID: 3, Logon Time: 2025-04-14 14:15:00, Duration: 01:15:01)
[2025-04-14 15:30:01] [INFO]   → Logging off user jsmith (Session exceeds threshold of 60 minutes)
[2025-04-14 15:30:02] [INFO]   → User jsmith has been logged off successfully
[2025-04-14 15:30:02] [INFO] User testuser is disconnected (Session ID: 4, Logon Time: 2025-04-14 15:15:30, Duration: 00:14:31)
[2025-04-14 15:30:02] [INFO]   → User testuser is disconnected but under threshold (00:14:31 < 60 minutes) - skipping
[2025-04-14 15:30:02] [INFO] Total sessions found: 5
[2025-04-14 15:30:02] [INFO] Active sessions: 2
[2025-04-14 15:30:02] [INFO] Disconnected sessions: 3
[2025-04-14 15:30:02] [INFO] Actions taken:
[2025-04-14 15:30:02] [INFO]   • Users logged off: 1
[2025-04-14 15:30:02] [INFO]   • Whitelisted users skipped: 1
[2025-04-14 15:30:02] [INFO]   • Users under disconnect threshold: 1
[2025-04-14 15:30:02] [INFO] -----------------------------------
[2025-04-14 15:30:03] [INFO] Script completed successfully
```
## Troubleshooting

If the script isn't working as expected:

1. Check the log file for error messages and session details
2. Review the session summary at the end of the log to understand what actions were taken
3. Ensure the script is running with administrator privileges
4. Verify the whitelist contains the correct usernames using the `-ShowUsernames` parameter
5. Check session durations and idle times in the logs to verify threshold settings
6. Make sure the log directory exists and is writable

The enhanced logging provides detailed information about each session and the decisions made, making it easier to diagnose issues.

## Notes

- The script requires administrator privileges to query sessions and log off users
- Users in the whitelist will never be logged off by this script
- The script will only log off users in the "Disconnected" state
- Modify the disconnect threshold in config.json to change how long users can remain disconnected

