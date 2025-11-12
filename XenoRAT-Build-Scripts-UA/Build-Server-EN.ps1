# XenoRAT Server Setup Script
# Requires Administrator privileges

# Configuration parameters
$Port = 8080  # Specify required port
$RuleName = "ZaUkraine TCP Listener"

Write-Host "=== Windows Server Setup for Xeno RAT ===" -ForegroundColor Cyan

# 1. Check administrator rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] Script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# 2. Get public IP address
Write-Host "`n[Step 1/5] Determining public IP address..." -ForegroundColor Yellow
try {
    $PublicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 10).Trim()
    Write-Host "Public IP: $PublicIP" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Failed to determine public IP automatically." -ForegroundColor Yellow
    Write-Host "Use the IP address provided by your hosting provider." -ForegroundColor Yellow
    $PublicIP = "SPECIFY_YOUR_IP"
}

# 3. Configure firewall rule
Write-Host "`n[Step 2/5] Creating firewall rule for port $Port..." -ForegroundColor Yellow

# Check if rule with this name exists
$existingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Rule '$RuleName' already exists. Removing old rule..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName $RuleName
}

# Create new rule
try {
    New-NetFirewallRule `
        -DisplayName $RuleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $Port `
        -Action Allow `
        -Profile Domain,Private,Public `
        -Description "Allows incoming TCP connections for Xeno RAT Server on port $Port"
    
    Write-Host "Firewall rule successfully created!" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create firewall rule: $_" -ForegroundColor Red
    exit 1
}

# 4. Disable IE Enhanced Security Configuration
Write-Host "`n[Step 3/5] Disabling IE Enhanced Security Configuration..." -ForegroundColor Yellow

try {
    # For Administrators
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" `
        -Name "IsInstalled" -Value 0 -ErrorAction Stop
    
    # For Users
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" `
        -Name "IsInstalled" -Value 0 -ErrorAction Stop
    
    Write-Host "IE Enhanced Security successfully disabled!" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Failed to disable IE Enhanced Security: $_" -ForegroundColor Yellow
}

# 5. Check .NET Framework version
Write-Host "`n[Step 4/5] Checking .NET Framework version..." -ForegroundColor Yellow

try {
    $dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
    
    if ($dotNetVersion -ge 528040) {
        $versionName = switch ($dotNetVersion) {
            { $_ -ge 533320 } { "4.8.1" }
            { $_ -ge 528040 } { "4.8" }
            default { "4.x" }
        }
        Write-Host ".NET Framework $versionName installed (Release: $dotNetVersion)" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Outdated .NET Framework version installed!" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Failed to determine .NET Framework version: $_" -ForegroundColor Yellow
}

# 6. Check port availability
Write-Host "`n[Step 5/5] Checking port $Port availability..." -ForegroundColor Yellow

$portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue

if ($portInUse) {
    Write-Host "[WARNING] Port $Port is already in use by process:" -ForegroundColor Yellow
    Get-Process -Id $portInUse.OwningProcess | Select-Object Id, ProcessName, Path
    Write-Host "It is recommended to choose another port or stop the conflicting process." -ForegroundColor Yellow
} else {
    Write-Host "Port $Port is free and ready to use!" -ForegroundColor Green
}

# Final information
Write-Host "`n=== Setup completed ===" -ForegroundColor Cyan
Write-Host "`nParameters for Builder:" -ForegroundColor White
Write-Host "  IP/Host: $PublicIP" -ForegroundColor White
Write-Host "  Port: $Port" -ForegroundColor White
Write-Host "`nSecurity recommendations:" -ForegroundColor Yellow
Write-Host "  - Use a strong unique Encryption Key" -ForegroundColor Yellow
Write-Host "  - Use a strong unique Mutex" -ForegroundColor Yellow
Write-Host "  - Consider using a non-standard port (not 8080)" -ForegroundColor Yellow
Write-Host "  - Regularly check server logs" -ForegroundColor Yellow