#Requires -RunAsAdministrator
<#
**************************************************************************************************************************************
Name:               Citrix-Workspace-App
Author:             Kasper Johansen
Website:            https://virtualwarlock.net            

*******************************************************************************************************************************************

.DESCRIPTION
    This script installs the latest Citrix Workspace App Current Release
    Using the Evergreen module created by Aaron Parker, Bronson Mangan and Trond Eric Haavarstein
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

# Configure Evergreen variables to download the lastest 64-bit version of Microsoft Edge stable release
$Vendor = "Citrix"
$Product = "Workspace App"
$Evergreen = Get-CitrixWorkspaceApp | where {$_.Title -eq "Citrix Workspace - Current Release"}
$Version = $Evergreen.Version
$PackageName = "CitrixWorkspaceApp$Version"
$URL = $Evergreen.uri
$InstallerType = "exe"
$Source = "$PackageName" + "." + "$InstallerType"
$Destination = "C:\Temp" + "\$Vendor\$Product\$Version"

# Application install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "/noreboot /silent /includeSSON ENABLE_SSON=Yes EnableCEIP=False"

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
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Destination\$Source

Write-Host "Installing $Vendor $Product v$Version" -ForegroundColor Cyan
Write-Host ""
Start-Process -FilePath $Destination\$Source -Wait -ArgumentList $InstallArguments

# Application post deployment tasks
Write-Host "Applying $Vendor $Product post setup customizations" -ForegroundColor Cyan

# Suppress the "Add Account" popup
New-ItemProperty -Path "HKLM:SOFTWARE\Software\Citrix" -Name ReceiverHideAddAccountOnRestart -Value 1 -PropertyType DWORD
New-ItemProperty -Path "HKLM:SOFTWARE\Software\Citrix" -Name EnableFTU -Value 0