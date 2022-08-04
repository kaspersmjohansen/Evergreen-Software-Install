#Requires -RunAsAdministrator
<#
*************************************************************************************************
Name:               
Author:             Kasper Johansen
Website:            https://virtualwarlock.net            

*************************************************************************************************
.DESCRIPTION
    This script installs the latest Putty 
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
$Vendor = "Simon Tatham"
$Product = "Putty"
$EvergreenApp = Get-EvergreenApp -Name PuTTY | Where-Object {$_.Architecture -eq "x64"}
$EvergreenAppInstaller = Split-Path -Path $EvergreenApp.Uri -Leaf
$EvergreenAppURL = $EvergreenApp.uri
$EvergreenAppVersion = $EvergreenApp.Version
$Destination = "C:\Temp\$Vendor $Product"

# Application install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "REBOOT=ReallySuppress /qn"

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