param (
    [Parameter(Mandatory = $false)]
    [switch]$ShowUsernames
)

<#
.SYNOPSIS
    PowerShell script to log off disconnected user sessions while respecting a whitelist.

.DESCRIPTION
    This script identifies disconnected user sessions on a Windows system, 
    and logs them off if they have been disconnected for longer than a specified threshold.
    Users in the whitelist are exempted from being logged off.

.NOTES
    File Name      : LogOffDisconnectedUsers.ps1
    Prerequisites  : PowerShell 5.1 or higher, Administrator rights
    
.EXAMPLE
    .\LogOffDisconnectedUsers.ps1
    
    Run the script to log off disconnected users according to the config.json settings.

.EXAMPLE
    .\LogOffDisconnectedUsers.ps1 -ShowUsernames
    
    Displays the usernames of currently logged-in users in the format needed for the whitelist.
#>

# Ensure we stop on errors
$ErrorActionPreference = "Stop"
# Script Variables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path -Path $scriptPath -ChildPath "config.json"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$exitCode = 0

# Default log file path (used if config file can't be loaded)
$defaultLogDir = Join-Path -Path $scriptPath -ChildPath "logs"
$defaultLogFile = Join-Path -Path $defaultLogDir -ChildPath "LogOffDisconnected.log"

# Create the default log directory if it doesn't exist
if (-not (Test-Path -Path $defaultLogDir)) {
    try {
        New-Item -Path $defaultLogDir -ItemType Directory -Force | Out-Null
    }
    catch {
        Write-Host "Failed to create log directory: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Initialize config variable
$script:config = $null

# Try to load configuration first
try {
    if (Test-Path -Path $configFile) {
        $script:config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
        
        # Basic validation
        if (-not $config.LogFilePath) {
            Write-Host "LogFilePath not found in config, using default: $defaultLogFile" -ForegroundColor Yellow
            $script:config | Add-Member -MemberType NoteProperty -Name "LogFilePath" -Value $defaultLogFile -Force
        }
    }
    else {
        Write-Host "Configuration file not found at $configFile, using defaults" -ForegroundColor Yellow
        $script:config = [PSCustomObject]@{
            WhitelistedUsers = @()
            DisconnectThresholdMinutes = 60
            LogFilePath = $defaultLogFile
        }
    }
}
catch {
    Write-Host "Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
    $script:config = [PSCustomObject]@{
        WhitelistedUsers = @()
        DisconnectThresholdMinutes = 60
        LogFilePath = $defaultLogFile
    }
}
# Function to write log messages
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        
        # Determine log path (with fallback)
        $logPath = if ($script:config -and $script:config.LogFilePath) { 
            $script:config.LogFilePath 
        } else { 
            $defaultLogFile 
        }
        
        # Create log directory if it doesn't exist
        $logDir = Split-Path -Parent $logPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        Add-Content -Path $logPath -Value $logMessage
        
        # Also output to console for interactive sessions
        switch ($Level) {
            "INFO" { Write-Host $logMessage -ForegroundColor Green }
            "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
            "ERROR" { Write-Host $logMessage -ForegroundColor Red }
            default { Write-Host $logMessage }
        }
    }
    catch {
        Write-Host "Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to parse the quser output
function Parse-UserSessions {
    try {
        $quserOutput = quser 2>&1
        
        # Check if the command was successful
        if ($LASTEXITCODE -ne 0) {
            throw "quser command failed with exit code: $LASTEXITCODE"
        }
        
        $sessions = @()
        
        # Skip the header row (first line)
        for ($i = 1; $i -lt $quserOutput.Count; $i++) {
            $line = $quserOutput[$i].Trim()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Parse the line - quser output format can be tricky
            # The username might have leading '>' if it's the current session
            if ($line -match '^>?\s*(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(.+)$') {
                $username = $matches[1]
                $sessionName = $matches[2]
                $sessionId = $matches[3]
                $state = $matches[4]
                $idleTimeLogonTime = $matches[5]
                
                # Parse idle time and logon time from the remaining string
                $idleTimeMatch = $idleTimeLogonTime -match '(\S+)\s+(.+)'
                $idleTime = $matches[1]
                $logonTime = $matches[2]
                
                $sessions += [PSCustomObject]@{
                    Username = $username
                    SessionName = $sessionName
                    SessionId = $sessionId
                    State = $state
                    IdleTime = $idleTime
                    LogonTime = try { [DateTime]::Parse($logonTime) } catch { $null }
                }
            }
            else {
                Write-Log "Failed to parse line: $line" -Level "WARNING"
            }
        }
        
        return $sessions
    }
    catch {
        Write-Log "Error parsing user sessions: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Function to check if a user is whitelisted
function Test-UserWhitelisted {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    return $config.WhitelistedUsers -contains $Username
}

# Function to calculate idle duration
function Get-IdleDuration {
    param (
        [string]$IdleTime
    )
    
    # Handle special case
    if ($IdleTime -eq "none" -or [string]::IsNullOrWhiteSpace($IdleTime)) {
        return [TimeSpan]::Zero
    }
    
    try {
        if ($IdleTime -match '(\d+)\+(\d+):(\d+)') {
            # Format: days+hours:minutes
            $days = [int]$matches[1]
            $hours = [int]$matches[2]
            $minutes = [int]$matches[3]
            return New-TimeSpan -Days $days -Hours $hours -Minutes $minutes
        }
        elseif ($IdleTime -match '(\d+):(\d+)') {
            # Format: hours:minutes
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            return New-TimeSpan -Hours $hours -Minutes $minutes
        }
        else {
            # Unknown format
            Write-Log "Unknown idle time format: $IdleTime" -Level "WARNING"
            return [TimeSpan]::Zero
        }
    }
    catch {
        Write-Log "Error parsing idle time '$IdleTime': $($_.Exception.Message)" -Level "WARNING"
        return [TimeSpan]::Zero
    }
}

# Function to show usernames in the format needed for whitelist
function Show-UserWhitelistFormat {
    Write-Host "`n===== Username Format for Whitelist =====" -ForegroundColor Cyan
    
    try {
        $quserOutput = quser 2>&1
        
        # Check if the command was successful
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No users are currently logged in or you don't have permission to view them." -ForegroundColor Yellow
            return
        }
        
        Write-Host "`nCurrently logged in users (use these exact usernames in whitelist):" -ForegroundColor Green
        
        # Skip the header row (first line)
        $foundUsers = $false
        for ($i = 1; $i -lt $quserOutput.Count; $i++) {
            $line = $quserOutput[$i].Trim()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Parse the line to extract username
            if ($line -match '^>?\s*(\S+)\s+') {
                $username = $matches[1]
                Write-Host "  • $username" -ForegroundColor White
                $foundUsers = $true
            }
        }
        
        if (-not $foundUsers) {
            Write-Host "  No users found" -ForegroundColor Yellow
        }
        
        # Username format explanation
        Write-Host "`nUsername Format Notes:" -ForegroundColor Yellow
        Write-Host "  • Use the exact username as shown above without domain prefixes"
        Write-Host "  • The script matches against the username shown in the 'quser' command output"
        Write-Host "  • Local accounts typically appear as just the username (e.g., 'admin')"
        Write-Host "  • Domain accounts may appear differently depending on your environment"
        Write-Host "  • The format may vary by Windows version and domain configuration"
        
        # Show format examples
        Write-Host "`nUsername Format Examples:" -ForegroundColor Magenta
        Write-Host "  • Local accounts: 'admin', 'user1'"
        Write-Host "  • Domain accounts: Usually shown without domain prefix in quser"
        Write-Host "    - If quser shows 'jsmith', use that exact format"
        Write-Host "    - Do NOT use 'DOMAIN\\jsmith' unless quser shows it that way"
        
        # Example config
        Write-Host "`nExample config.json:" -ForegroundColor Magenta
        $exampleConfig = @{
            WhitelistedUsers = @("admin", "serviceaccount", "jsmith", "masonherbel")
            LogFilePath = ".\\logs\\LogOffDisconnected.log"
        } | ConvertTo-Json -Depth 3
        
        Write-Host $exampleConfig
        
        # Current config info
        if (Test-Path -Path $configFile) {
            try {
                $currentConfig = Get-Content -Path $configFile -Raw | ConvertFrom-Json
                Write-Host "`nCurrent whitelisted users:" -ForegroundColor Cyan
                
                if ($currentConfig.WhitelistedUsers -and $currentConfig.WhitelistedUsers.Count -gt 0) {
                    foreach ($user in $currentConfig.WhitelistedUsers) {
                        Write-Host "  • $user" -ForegroundColor White
                    }
                } else {
                    Write-Host "  No users are currently whitelisted" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error reading current configuration: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "`n===== End of Username Format Guide =====" -ForegroundColor Cyan
    } catch {
        Write-Host "Error retrieving user information: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main script execution

# Check if we're just showing username format
if ($ShowUsernames) {
    Show-UserWhitelistFormat
    exit 0
}

try {
    Write-Log "Script started"
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "Script must be run with administrator privileges" -Level "ERROR"
        exit 1
    }
    
    # Additional configuration validation
    if (-not $script:config) {
        Write-Log "No configuration available, using defaults" -Level "WARNING"
    }
    else {
        # Validate whitelisted users and threshold
        if (-not $script:config.WhitelistedUsers) {
            Write-Log "No whitelisted users specified" -Level "WARNING"
            $script:config.WhitelistedUsers = @()
        }
        
        if (-not $script:config.DisconnectThresholdMinutes) {
            Write-Log "No disconnect threshold specified, using default of 60 minutes" -Level "WARNING"
            $script:config | Add-Member -MemberType NoteProperty -Name "DisconnectThresholdMinutes" -Value 60 -Force
        }
    }
    
    Write-Log "Configuration loaded successfully"
    
    # Get user sessions
    $sessions = Parse-UserSessions
    
    if ($sessions.Count -eq 0) {
        Write-Log "No user sessions found"
        exit 0
    }
    
    Write-Log "Found $($sessions.Count) user sessions"
    
    # Log session details summary
    Write-Log "Session details summary:" -Level "INFO"
    foreach ($session in $sessions) {
        $isWhitelisted = Test-UserWhitelisted -Username $session.Username
        $whitelistStatus = if ($isWhitelisted) { "WHITELISTED" } else { "not whitelisted" }
        Write-Log "  • User: $($session.Username), State: $($session.State), Session ID: $($session.SessionId), $whitelistStatus" -Level "INFO"
    }
    
    # Process sessions
    $disconnectedThreshold = New-TimeSpan -Minutes $config.DisconnectThresholdMinutes
    $now = Get-Date
    
    # Session counters for summary
    $activeCount = 0
    $disconnectedCount = 0
    $whitelistedCount = 0
    $loggedOffCount = 0
    $underThresholdCount = 0
    foreach ($session in $sessions) {
        $username = $session.Username
        $sessionId = $session.SessionId
        $isWhitelisted = Test-UserWhitelisted -Username $username
        
        # Calculate session duration and idle time for all users
        $sessionDuration = $null
        $idleDuration = $null
        $timeDisplay = "unknown"
        $logonTimeStr = "unknown"
        
        if ($session.LogonTime -ne $null) {
            $sessionDuration = $now - $session.LogonTime
            $idleDuration = Get-IdleDuration -IdleTime $session.IdleTime
            $logonTimeStr = $session.LogonTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            # If idle time is available, use it, otherwise use session duration for display
            if ($idleDuration -gt [TimeSpan]::Zero) {
                $timeDisplay = $idleDuration.ToString()
            } else {
                $timeDisplay = $sessionDuration.ToString()
            }
        }
        
        # Log detailed information for all sessions
        if ($session.State -eq "Active") {
            Write-Log "User $username is active (Session ID: $sessionId, Logon Time: $logonTimeStr, Duration: $timeDisplay)" -Level "INFO"
            $activeCount++
        }
        elseif ($session.State -eq "Disc") {
            $disconnectedCount++
            $disconnectedLongEnough = $false
            
            if ($sessionDuration -ne $null) {
                # Determine if the session has been disconnected long enough
                if ($idleDuration -gt [TimeSpan]::Zero) {
                    $disconnectedLongEnough = $idleDuration -ge $disconnectedThreshold
                } else {
                    $disconnectedLongEnough = $sessionDuration -ge $disconnectedThreshold
                }
                
                # Log detailed disconnected session info
                Write-Log "User $username is disconnected (Session ID: $sessionId, Logon Time: $logonTimeStr, Duration: $timeDisplay)" -Level "INFO"
                
                # Process disconnected sessions
                if ($isWhitelisted) {
                    Write-Log "  → User $username is whitelisted - skipping" -Level "INFO"
                    $whitelistedCount++
                }
                else {
                    if ($disconnectedLongEnough) {
                        # Log off the user
                        try {
                            Write-Log "  → Logging off user $username (Session exceeds threshold of $($config.DisconnectThresholdMinutes) minutes)" -Level "INFO"
                            logoff $sessionId
                            Write-Log "  → User $username has been logged off successfully" -Level "INFO"
                            $loggedOffCount++
                        }
                        catch {
                            Write-Log "  → Failed to log off user ${username}: $($_.Exception.Message)" -Level "ERROR"
                            $exitCode = 1
                        }
                    }
                    else {
                        Write-Log "  → User $username is disconnected but under threshold ($timeDisplay < $($config.DisconnectThresholdMinutes) minutes) - skipping" -Level "INFO"
                        $underThresholdCount++
                    }
                }
            }
            else {
                Write-Log "Unable to determine session duration for user $username (Session ID: $sessionId)" -Level "WARNING"
            }
        }
        else {
            # Other states (e.g., "Conn" for connecting)
            Write-Log "User $username has state '$($session.State)' (Session ID: $sessionId, Duration: $timeDisplay)" -Level "INFO"
        }
    }
    
    # Log session summary
    Write-Log "Total sessions found: $($sessions.Count)" -Level "INFO"
    Write-Log "Active sessions: $activeCount" -Level "INFO"
    Write-Log "Disconnected sessions: $disconnectedCount" -Level "INFO"
    Write-Log "Actions taken:" -Level "INFO"
    Write-Log "  • Users logged off: $loggedOffCount" -Level "INFO"
    Write-Log "  • Whitelisted users skipped: $whitelistedCount" -Level "INFO"
    Write-Log "  • Users under disconnect threshold: $underThresholdCount" -Level "INFO"
    Write-Log "-----------------------------------" -Level "INFO"
    
    Write-Log "Script completed successfully"
}
catch {
    Write-Log "Unhandled exception: $($_.Exception.Message)" -Level "ERROR"
    $exitCode = 1
}
finally {
    exit $exitCode
}

