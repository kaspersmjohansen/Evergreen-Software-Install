#Requires -RunAsAdministrator
<#
*************************************************************************************************
Name:               Microsoft-FSLogix-Apps-Agent-Evergreen
Author:             Kasper Johansen
Website:            https://virtualwarlock.net            

*************************************************************************************************

.DESCRIPTION
    This script installs the latest Microsoft FSLogix Apps Agent 
    using the Evergreen module created by Aaron Parker, Bronson Mangan and Trond Eric Haavarstein
    https://github.com/aaronparker/Evergreen

    Post setup customizations are explained here:
    https://virtualwarlock.net/how-to-install-the-fslogix-apps-agent/

*************************************************************************************************
#>

# Clear screen
cls

# Configure security protocol to use TLS 1.2 for new connections
Write-Host "Configuring TLS1.2 security protocol for new connections" -ForegroundColor Cyan
Write-Host ""
[Net.ServicePointManager]::SecurityProtocol = "tls12"

# Download latest NuGet Package Provider
If (!(Test-Path -Path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget"))
{
Write-Host "Installing latest NuGet Package Provider" -ForegroundColor Cyan
Write-Host ""
Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies | Out-Null
}    

# Download latest Evergreen module
Write-Host "Installing latest Evergreen module" -ForegroundColor Cyan
Write-Host ""
If (!(Get-Module -ListAvailable -Name Evergreen))
{
Install-Module Evergreen -Force | Import-Module Evergreen
}
else
{
Update-Module Evergreen -Force
}

# Configure Evergreen variables
$Vendor = "Microsoft"
$Product = "FSLogix Apps Agent"
$EvergreenApp = Get-EvergreenApp -Name MicrosoftFSLogixApps | Where-Object {$_.Channel -eq "Production" } | Sort-Object -Property Version -Descending | Select-Object -First 1
$EvergreenAppInstaller = Split-Path -Path $EvergreenApp.Uri -Leaf
$EvergreenAppURL = $EvergreenApp.uri
$EvergreenAppVersion = $EvergreenApp.Version
$Destination = "C:\Temp\$Vendor $Product"
$OS = (Get-WmiObject Win32_OperatingSystem).Caption

# Application install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "/install /quiet /norestart"

# Create destination folder, if not exist
If (!(Test-Path -Path $Destination))
{
Write-Host "Creating $Destination" -ForegroundColor Cyan
Write-Host ""
New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Download and deploy application
Write-Host "Downloading latest $Vendor $Product release" -ForegroundColor Cyan
Write-Host ""
Invoke-WebRequest -UseBasicParsing -Uri $EvergreenAppURL -OutFile $Destination\$EvergreenAppInstaller

# Expand the FSLogix Apps Zip file
Expand-Archive -Path $Destination\$EvergreenAppInstaller -DestinationPath "$Destination"

# Deploy Microsoft FSLogix Apps Agent
Write-Host "Installing $Vendor $Product v$EvergreenAppVersion" -ForegroundColor Cyan
Write-Host ""
Start-Process -FilePath "$Destination\x64\Release\FSLogixAppsSetup.exe" -Wait -ArgumentList $InstallArguments

# Application post deployment tasks
Write-Host "Applying post setup customizations" -ForegroundColor Cyan
Write-Host ""

# Windows Search CoreCount modification
Write-Host "Modifying Windows Search service Core Count" -ForegroundColor Cyan
New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows Search" -Name "CoreCount" -Value "1" -Type DWORD

# Enable or disable FSLogix Apps agent search roaming - Apply different configurations based on operating system
If ($OS -Like "*Windows Server 2016*")
{
    Write-Host "Configuring FSLogix search roaming for $OS" -ForegroundColor Cyan
    Write-Host ""
    Set-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Apps" -Name "RoamSearch" -Value "2" -Type DWORD
}
        If ($OS -Like "*Windows Server 2019*" -or $OS -Like "*Windows Server 2022*" -or $OS -eq "Microsoft Windows 10 Enterprise for Virtual Desktops")
        {
            Write-Host "Configuring FSLogix search roaming for $OS" -ForegroundColor Cyan
            Write-Host ""
            Set-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Apps" -Name "RoamSearch" -Value "0" -Type DWORD
        }
            If ($OS -Like "*Windows 10*" -and $OS -ne "Microsoft Windows 10 Enterprise for Virtual Desktops")
            {
                Write-Host "Configuring FSLogix search roaming for $OS" -ForegroundColor Cyan
                Write-Host ""
                Set-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Apps" -Name "RoamSearch" -Value "1" -Type DWORD
            }

# Implement user based group policy processing fix
Write-Host "Configuring FSLogix user based group policy processing registry fix" -ForegroundColor Cyan
Write-Host ""
If (!(Test-Path -Path HKLM:SOFTWARE\FSLogix\Profiles))
{
New-Item -Path "HKLM:SOFTWARE\FSLogix" -Name Profiles
New-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Profiles" -Name "GroupPolicyState" -Value "0" -Type DWORD
}
else
{
New-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Profiles" -Name "GroupPolicyState" -Value "0" -Type DWORD
}

# Implement scheduled task to restart Windows Search service on Event ID 2 on Windows Server 2019
If ($OS -Like "*Windows Server 2019*" -or $OS -Like "*Windows Server 2022*")
{
Write-Host "Configuring Windows scheduled task workaround for the Windows Search issue in $OS" -ForegroundColor Cyan
Write-Host ""
# Define CIM object variables
# This is needed for accessing the non-default trigger settings when creating a schedule task using Powershell
$Class = cimclass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler
$Trigger = $class | New-CimInstance -ClientOnly
$Trigger.Enabled = $true
$Trigger.Subscription = "<QueryList><Query Id=`"0`" Path=`"Application`"><Select Path=`"Application`">*[System[Provider[@Name='Microsoft-Windows-Search-ProfileNotify'] and EventID=2]]</Select></Query></QueryList>"

# Define additional variables containing scheduled task action and scheduled task principal
$A = New-ScheduledTaskAction –Execute powershell.exe -Argument "Restart-Service Wsearch"
$P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
$S = New-ScheduledTaskSettingsSet

# Cook it all up and create the scheduled task
$RegSchTaskParameters = @{
    TaskName    = "Restart Windows Search Service on Event ID 2"
    Description = "Restarts the Windows Search service on event ID 2 - Workaround described here - https://virtualwarlock.net/how-to-install-the-fslogix-apps-agent/#Windows_Search_Roaming_workaround_1"
    TaskPath    = "\"
    Action      = $A
    Principal   = $P
    Settings    = $S
    Trigger     = $Trigger
}

Register-ScheduledTask @RegSchTaskParameters
}