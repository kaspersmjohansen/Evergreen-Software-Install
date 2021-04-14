#Requires -RunAsAdministrator
<#
*************************************************************************************************
Name:               Microsoft-Teams-Machine-Based-Evergreen
Author:             Kasper Johansen
Website:            https://virtualwarlock.net            

*************************************************************************************************
.DESCRIPTION
    This script installs the latest Microsoft Teams Machined-Based 
    using the Evergreen module created by Aaron Parker, Bronson Mangan and Trond Eric Haavarstein
    https://github.com/aaronparker/Evergreen

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
$Product = "Teams"
$EvergreenApp = Get-EvergreenApp -Name MicrosoftTeams | Where-Object {$_.Architecture -eq "x64" -and $_.Ring -eq "General"}
$EvergreenAppInstaller = Split-Path -Path $EvergreenApp.Uri -Leaf
$EvergreenAppURL = $EvergreenApp.uri
$EvergreenAppVersion = $EvergreenApp.Version
$Destination = "C:\Temp\$Vendor $Product"

# Application install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "REBOOT=ReallySuppress /qn ALLUSER=1 ALLUSERS=1"

# Create destination folder, if not exist
If (!(Test-Path -Path $Destination))
{
Write-Host "Creating $Destination" -ForegroundColor Cyan
Write-Host ""
New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Pre application deployment tasks
Write-Host "Applying $Vendor $Product pre setup customizations" -ForegroundColor Cyan
Write-Host ""

# Registry key for Teams machine-based install with Citrix VDA
New-Item -Path "HKLM:Software\Citrix"
New-Item -Path "HKLM:Software\Citrix\PortICA\"

# Registry value for Teams machine-based install with Windows Virtual Desktop
# New-Item -Path "HKLM:SOFTWARE\Microsoft\Teams"
# New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Teams" -Name IsWVDEnvironment -Value 1 -PropertyType DWORD

# Download and deploy application
Write-Host "Downloading latest $Vendor $Product release" -ForegroundColor Cyan
Write-Host ""
Invoke-WebRequest -UseBasicParsing -Uri $EvergreenAppURL -OutFile $Destination\$EvergreenAppInstaller

Write-Host "Installing $Vendor $Product v$EvergreenAppVersion" -ForegroundColor Cyan
Write-Host ""
Start-Process -FilePath $Destination\$EvergreenAppInstaller -Wait -ArgumentList $InstallArguments

# Application post deployment tasks
Write-Host "Applying $Vendor $Product post setup customizations" -ForegroundColor Cyan

# Remove public desktop shortcut
Remove-Item -Path "$env:PUBLIC\Desktop\Microsoft Teams.lnk" -Force

# Disable Teams auto start
Remove-ItemProperty -Path "HKLM:SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" -Name "Teams"