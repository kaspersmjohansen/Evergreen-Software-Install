#Requires -RunAsAdministrator
<#
*************************************************************************************************
Name:               Microsoft-Edge-Evergreen
Author:             Kasper Johansen
Website:            https://virtualwarlock.net            

*************************************************************************************************
.DESCRIPTION
    This script installs the latest Microsoft Edge 
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
$Product = "Edge"
$EvergreenApp = Get-EvergreenApp -Name MicrosoftEdge | Where-Object {$_.Architecture -eq "x64"}
$EvergreenAppInstaller = Split-Path -Path $EvergreenApp.Uri -Leaf
$EvergreenAppURL = $EvergreenApp.uri
$EvergreenAppVersion = $EvergreenApp.Version
$Destination = "C:\Temp\$Vendor $Product"

# Application install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "REBOOT=ReallySuppress /qn DONOTCREATEDESKTOPSHORTCUT=true DONOTCREATETASKBARSHORTCUT=true"

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

Write-Host "Installing $Vendor $Product v$EvergreenAppVersion" -ForegroundColor Cyan
Write-Host ""
Start-Process -FilePath $Destination\$EvergreenAppInstaller -Wait -ArgumentList $InstallArguments

# Application post deployment tasks
Write-Host "Applying post setup customizations" -ForegroundColor Cyan

# Disable Microsoft Edge auto update
If (!(Test-Path -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate))
{
New-Item -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate
New-ItemProperty -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate -Name UpdateDefault -Value 0 -PropertyType DWORD
}
else
{
New-ItemProperty -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate -Name UpdateDefault -Value 0 -PropertyType DWORD
}

# Disable Microsoft Edge scheduled tasks
Get-ScheduledTask -TaskName MicrosoftEdgeUpdate* | Disable-ScheduledTask | Out-Null

# Configure Microsoft Edge update service to manual startup
Set-Service -Name edgeupdate -StartupType Manual

# Execute the Microsoft Edge browser replacement task to make sure that the legacy Microsoft Edge browser is tucked away
# This is only needed on Windows 10 versions where Microsoft Edge is not included in the OS.
Start-Process -FilePath "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -Wait -ArgumentList "/browserreplacement"