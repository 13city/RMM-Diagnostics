# Comprehensive System Health Monitor and Support Guide
# Version: 1.0
# Last Updated: 2024-12-24
#
# This script provides:
# 1. System health monitoring
# 2. Early warning detection
# 3. Detailed troubleshooting steps
# 4. Slack and email alerting
# 5. Support guidance for resolution

param(
    [Parameter(Mandatory=$true)]
    [string]$SlackWebhook,
    
    [Parameter(Mandatory=$false)]
    [string]$EmailRecipient,
    
    [Parameter(Mandatory=$false)]
    [string]$SmtpServer = "smtp.company.com",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\ProgramData\ITMonitoring\Logs",
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\ProgramData\ITMonitoring\Reports",
    
    [Parameter(Mandatory=$false)]
    [int]$DiskSpaceThreshold = 15,
    
    [Parameter(Mandatory=$false)]
    [int]$CpuThreshold = 85,
    
    [Parameter(Mandatory=$false)]
    [int]$MemoryThreshold = 90,
    
    [Parameter(Mandatory=$false)]
    [int]$EventLogDays = 3
)

# Emoji mappings for status indicators
$script:emoji = @{
    Critical = "🚨"
    Warning = "⚠️"
    Info = "ℹ️"
    Success = "✅"
    CPU = "🔄"
    Memory = "💾"
    Disk = "💿"
    Network = "🌐"
    Security = "🔒"
    Updates = "🔄"
    Services = "⚙️"
    Performance = "📈"
    Hardware = "🔧"
    Software = "📀"
}

function Initialize-Environment {
    try {
        # Create necessary directories
        @($LogPath, $ReportPath) | ForEach-Object {
            if (-not (Test-Path $_)) {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
            }
        }
        
        # Start logging
        $script:LogFile = Join-Path $LogPath "$(Get-Date -Format 'yyyy-MM-dd')-SystemHealth.log"
        Write-Log "Starting system health check"
        
        # Import required modules
        $requiredModules = @('CimCmdlets', 'Microsoft.PowerShell.Diagnostics')
        foreach ($module in $requiredModules) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-Log "Required module not found: $module" -Level Critical
                throw "Required module not found: $module"
            }
        }
    }
    catch {
        throw "Failed to initialize environment: $_"
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Critical', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $logMessage
}

function Send-SlackAlert {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Critical', 'Success')]
        [string]$Level = 'Info',
        [array]$Fields,
        [array]$Actions
    )
    
    $color = switch($Level) {
        'Info' { '#36a64f' }
        'Warning' { '#ffcc00' }
        'Critical' { '#ff0000' }
        'Success' { '#2eb886' }
    }
    
    $payload = @{
        attachments = @(
            @{
                color = $color
                title = $Title
                text = $Message
                fields = $Fields | ForEach-Object {
                    @{
                        title = $_.Title
                        value = $_.Value
                        short = $_.Short
                    }
                }
                actions = $Actions
                footer = "System Health Monitor - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            }
        )
    }
    
    try {
        $json = $payload | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $SlackWebhook -Method Post -Body $json -ContentType 'application/json'
        Write-Log "Slack alert sent: $Title"
    }
    catch {
        Write-Log "Failed to send Slack alert: $_" -Level Critical
    }
}

function Get-SystemInfo {
    try {
        Write-Log "Collecting system information"
        
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $operatingSystem = Get-CimInstance Win32_OperatingSystem
        $bios = Get-CimInstance Win32_BIOS
        $processor = Get-CimInstance Win32_Processor
        $networkAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter }
        
        return @{
            ComputerName = $computerSystem.Name
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
            SystemType = $computerSystem.SystemType
            Domain = $computerSystem.Domain
            OS = "$($operatingSystem.Caption) $($operatingSystem.Version)"
            LastBoot = $operatingSystem.LastBootUpTime
            BIOSVersion = $bios.SMBIOSBIOSVersion
            SerialNumber = $bios.SerialNumber
            Processor = $processor.Name
            Memory = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
            NetworkAdapters = $networkAdapters | Select-Object Name, NetConnectionID, Speed
        }
    }
    catch {
        Write-Log "Failed to collect system information: $_" -Level Critical
        throw
    }
}

function Test-DiskSpace {
    try {
        Write-Log "Checking disk space"
        
        $issues = @()
        $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        
        foreach ($disk in $disks) {
            $freeSpacePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            
            if ($freeSpacePercent -lt $DiskSpaceThreshold) {
                $issue = @{
                    Component = "Storage"
                    Severity = if ($freeSpacePercent -lt ($DiskSpaceThreshold / 2)) { "Critical" } else { "Warning" }
                    Drive = $disk.DeviceID
                    FreeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
                    TotalSpace = [math]::Round($disk.Size / 1GB, 2)
                    FreePercent = $freeSpacePercent
                    Impact = "Low disk space can cause system instability and application failures"
                    CheckSteps = @(
                        "1. Open File Explorer and navigate to $($disk.DeviceID)\"
                        "2. Right-click drive and select 'Properties'"
                        "3. Click 'Disk Cleanup' and run as administrator"
                        "4. Check 'Windows Update Cleanup' and 'Previous Windows installations'"
                        "5. Use WinDirStat or TreeSize to identify large files"
                    )
                    ResolutionSteps = @(
                        "1. Clean temporary files: Run 'cleanmgr.exe /sageset:65535'"
                        "2. Clear Windows Update cache: Stop Windows Update service and delete contents of C:\Windows\SoftwareDistribution"
                        "3. Uninstall unnecessary applications"
                        "4. Move large files to external storage"
                        "5. Consider disk upgrade if persistent issue"
                    )
                }
                $issues += $issue
            }
        }
        
        return $issues
    }
    catch {
        Write-Log "Failed to check disk space: $_" -Level Critical
        throw
    }
}

function Test-SystemPerformance {
    try {
        Write-Log "Checking system performance"
        
        $issues = @()
        
        # CPU Check
        $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3).CounterSamples.CookedValue | 
            Measure-Object -Average | 
            Select-Object -ExpandProperty Average
        
        if ($cpuLoad -gt $CpuThreshold) {
            $issue = @{
                Component = "CPU"
                Severity = if ($cpuLoad -gt 95) { "Critical" } else { "Warning" }
                Usage = [math]::Round($cpuLoad, 2)
                Impact = "High CPU usage can cause system slowdown and application unresponsiveness"
                CheckSteps = @(
                    "1. Open Task Manager (Ctrl+Shift+Esc)"
                    "2. Sort by CPU usage"
                    "3. Identify resource-intensive processes"
                    "4. Check Process Timeline for patterns"
                    "5. Review CPU temperature in BIOS or monitoring tool"
                )
                ResolutionSteps = @(
                    "1. End unnecessary resource-intensive processes"
                    "2. Check for malware using Windows Defender"
                    "3. Update or reinstall problematic applications"
                    "4. Clean system fans and heat sinks"
                    "5. Consider hardware upgrade if persistent"
                )
            }
            $issues += $issue
        }
        
        # Memory Check
        $memory = Get-CimInstance Win32_OperatingSystem
        $memoryUsage = [math]::Round(($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize * 100, 2)
        
        if ($memoryUsage -gt $MemoryThreshold) {
            $issue = @{
                Component = "Memory"
                Severity = if ($memoryUsage -gt 95) { "Critical" } else { "Warning" }
                Usage = $memoryUsage
                Impact = "High memory usage can cause system slowdown and application crashes"
                CheckSteps = @(
                    "1. Open Resource Monitor (resmon.exe)"
                    "2. Check Memory tab for usage patterns"
                    "3. Identify memory-intensive processes"
                    "4. Review committed memory trends"
                    "5. Check for memory leaks"
                )
                ResolutionSteps = @(
                    "1. Close unnecessary applications"
                    "2. Clear browser cache and tabs"
                    "3. Restart memory-intensive applications"
                    "4. Check for application updates"
                    "5. Consider memory upgrade if persistent"
                )
            }
            $issues += $issue
        }
        
        return $issues
    }
    catch {
        Write-Log "Failed to check system performance: $_" -Level Critical
        throw
    }
}

function Test-EventLogs {
    try {
        Write-Log "Checking event logs"
        
        $issues = @()
        $startTime = (Get-Date).AddDays(-$EventLogDays)
        
        # Critical Windows Events to check
        $eventChecks = @(
            @{
                LogName = 'System'
                Level = 2  # Error
                ID = @(41, 55, 1001, 6008)  # System crashes, disk errors
            },
            @{
                LogName = 'Application'
                Level = 2
                ID = @(1000, 1002)  # Application crashes
            },
            @{
                LogName = 'Security'
                Level = 2
                ID = @(4625, 4648, 4719)  # Failed logins, explicit creds, policy changes
            }
        )
        
        foreach ($check in $eventChecks) {
            $events = Get-WinEvent -FilterHashtable @{
                LogName = $check.LogName
                Level = $check.Level
                ID = $check.ID
                StartTime = $startTime
            } -ErrorAction SilentlyContinue
            
            if ($events) {
                $grouped = $events | Group-Object ID
                
                foreach ($group in $grouped) {
                    $issue = @{
                        Component = "EventLog"
                        Severity = "Warning"
                        LogName = $check.LogName
                        EventID = $group.Name
                        Count = $group.Count
                        LastOccurrence = ($group.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
                        Impact = "Event log errors can indicate system stability or security issues"
                        CheckSteps = @(
                            "1. Open Event Viewer (eventvwr.msc)"
                            "2. Navigate to $($check.LogName)"
                            "3. Filter for Event ID $($group.Name)"
                            "4. Review event details and source"
                            "5. Check for patterns in occurrence"
                        )
                        ResolutionSteps = @(
                            "1. Research Event ID $($group.Name) in Microsoft docs"
                            "2. Check application logs if application-related"
                            "3. Verify system stability and recent changes"
                            "4. Update related drivers or software"
                            "5. Create monitoring rule for this event"
                        )
                    }
                    $issues += $issue
                }
            }
        }
        
        return $issues
    }
    catch {
        Write-Log "Failed to check event logs: $_" -Level Critical
        throw
    }
}

function Test-Services {
    try {
        Write-Log "Checking critical services"
        
        $issues = @()
        $criticalServices = @(
            'wuauserv',        # Windows Update
            'WinDefend',       # Windows Defender
            'wscsvc',          # Security Center
            'Schedule',        # Task Scheduler
            'EventLog',        # Event Log
            'BITS',            # Background Intelligence Transfer
            'CryptSvc',        # Cryptographic Services
            'Dhcp',            # DHCP Client
            'Dnscache',        # DNS Client
            'LanmanServer',    # Server
            'LanmanWorkstation', # Workstation
            'RpcSs',           # Remote Procedure Call
            'nsi',             # Network Store Interface Service
            'W32Time'          # Windows Time
        )
        
        foreach ($serviceName in $criticalServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            if (-not $service -or $service.Status -ne 'Running') {
                $issue = @{
                    Component = "Service"
                    Severity = "Warning"
                    ServiceName = $serviceName
                    Status = if ($service) { $service.Status } else { "Not Found" }
                    StartType = if ($service) { $service.StartType } else { "Unknown" }
                    Impact = "Stopped critical services can affect system functionality and security"