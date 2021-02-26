﻿#Requires -RunAsAdministrator
<#
**************************************************************************************************************************************
Name:               Microsoft-FSLogix-Apps
Author:             Kasper Johansen
Website:            https://virtualwarlock.net            

*******************************************************************************************************************************************

.SYNOPSIS
    This script installs Microsoft FSLogix Apps using the Evergreen module

.DESCRIPTION
    This script installs the latest Microsoft using the Evergreen module created by Aaron Parker, Bronson Mangan and Trond Eric Haavarstein
    https://github.com/aaronparker/Evergreen

*******************************************************************************************************************************************
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

# Configure Evergreen variables to download the lastest version of Microsoft FSLogix Apps release
$Vendor = "Microsoft"
$Product = "FSLogix Apps Agent"
$Evergreen = Get-MicrosoftFSLogixApps | Sort-Object -Property Version -Descending | Select-Object -First 1
$Version = $Evergreen.Version
$PackageName = "FSLogix_Apps_$version"
$URL = $Evergreen.uri
$InstallerType = "zip"
$Source = "$PackageName" + "." + "$InstallerType"
$Destination = "C:\Temp" + "\$Vendor\$Product\$Version"
$OS = (Get-WmiObject Win32_OperatingSystem).Caption

# Microsoft FSLogix Apps install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "/install /quiet /norestart"

# Create destination folder, if not exist
If (!(Test-Path -Path $Destination))
{
Write-Host "Creating $Destination" -ForegroundColor Cyan
Write-Host ""
New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Download Microsoft FSLogix Apps Agent
Write-Host "Downloading latest $Vendor $Product release" -ForegroundColor Cyan
Write-Host ""
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Destination\$Source

# Expand the FSLogix Apps ZIp file
Expand-Archive -Path $Destination\$Source -DestinationPath "$Destination"

# Deploy Microsoft FSLogix Apps Agent
Write-Host "Installing $Vendor $Product v$Version" -ForegroundColor Cyan
Write-Host ""
Start-Process -FilePath "$Destination\FSLogixAppsSetup.exe" -Wait -ArgumentList $InstallArguments

# Microsoft FSLogix Apps post deployment tasks
Write-Host "Applying $Vendor $Product post setup customizations" -ForegroundColor Cyan

# Windows Search CoreCount modification
New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows Search" -Name "CoreCount" -Value "1" -Type DWORD -Verbose

# Enable or disable FSLogix Apps agent search roaming - Apply different configurations based on operating system
If ($OS -Like "*Windows Server 2016*")
{
    New-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Apps" -Name "RoamSearch" -Value "2" -Type DWORD -Verbose
}
        If ($OS -Like "*Windows Server 2019*" -or $OS -eq "Microsoft Windows 10 Enterprise for Virtual Desktops")
        {
            New-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Apps" -Name "RoamSearch" -Value "0" -Type DWORD -Verbose
        }
            If ($OS -Like "*Windows 10*" -and $OS -ne "Microsoft Windows 10 Enterprise for Virtual Desktops")
            {
                New-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Apps" -Name "RoamSearch" -Value "1" -Type DWORD -Verbose
            }

# Implement user based group policy processing fix
New-ItemProperty -Path "HKLM:SOFTWARE\FSLogix\Profiles" -Name "GroupPolicyState" -Value "0" -Type DWORD -Verbose


# Implement scheduled task to restart Windows Search service on Event ID 2
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
    Description = "Restarts the Windows Search service on event ID 2"
    TaskPath    = "\"
    Action      = $A
    Principal   = $P
    Settings    = $S
    Trigger     = $Trigger
}

Register-ScheduledTask @RegSchTaskParameters