# Configure security protocol to use TLS 1.2 for new connections
Write-Host "Configuring TLS1.2 security protocol for new connections" -ForegroundColor Cyan
Write-Host ""
[Net.ServicePointManager]::SecurityProtocol = "tls12"

# Download latest NuGet Package Provider
If (!(Test-Path -Path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget"))
{
Write-Host "Downloading and installing latest NuGet Package Provider" -ForegroundColor Cyan
Write-Host ""
Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies
}    

# Download latest Evergreen module
If (!(Get-Module -ListAvailable -Name Evergreen))
{
Write-Host "Downloading and installing latest Evergreen module" -ForegroundColor Cyan
Write-Host ""
Install-Module Evergreen -Force | Import-Module Evergreen
}

# Configure Evergreen variables to download the lastest 64-bit version of Microsoft Edge stable release
$Vendor = "Microsoft"
$Product = "Edge"
$PackageName = "MicrosoftEdgeEnterpriseX64"
$Evergreen = Get-MicrosoftEdge | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" -and $_.Platform -eq "Windows" } | Sort-Object -Property Version -Descending | Select-Object -First 1
$Version = $Evergreen.Version
$URL = $Evergreen.uri
$InstallerType = "msi"
$Source = "$PackageName" + "." + "$InstallerType"
$Destination = "C:\Temp" + "\$Vendor\$Product\$Version"

# Microsoft Edge install arguments 
# This will prevent desktop and taskbar shortcuts from appearing during first logon 
$InstallArguments = "REBOOT=ReallySuppress /qn DONOTCREATEDESKTOPSHORTCUT=true DONOTCREATETASKBARSHORTCUT=true"

# Create destination folder, if not exist
If (!(Test-Path -Path $Destination))
{
Write-Host "Creating $Destination" -ForegroundColor Cyan
Write-Host ""
New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Download and deploy Microsoft Edge
Write-Host "Downloading latest $Vendor $Product" -ForegroundColor Cyan
Write-Host ""
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Destination\$Source

Write-Host "Installing $Vendor $Product" -ForegroundColor Cyan
Write-Host ""
Start-Process -FilePath $Destination\$Source -Wait -ArgumentList $InstallArguments

# Microsoft Edge post deployment tasks
# Disable Microsoft Edge auto update
If (!(Test-Path -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate))
{
New-Item -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate
New-ItemProperty -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate -Name UpdateDefault -Value 0 -PropertyType DWORD
}
else
{
Set-ItemProperty -Path HKLM:SOFTWARE\Policies\Microsoft\EdgeUpdate -Name UpdateDefault -Value 0
}

# Disable Microsoft Edge scheduled tasks
Get-ScheduledTask -TaskName MicrosoftEdgeUpdate* | Disable-ScheduledTask | Out-Null

# Configure Microsoft Edge update service to manual startup
Set-Service -Name edgeupdate -StartupType Manual

# Execute the Microsoft Edge browser replacement task
Start-Process -FilePath "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -Wait -ArgumentList "/browserreplacement"