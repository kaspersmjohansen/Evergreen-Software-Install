# Configure security protocol to use TLS 1.2 for new connections
Write-Host "Configuring TLS1.2 security protocol for new connections" -ForegroundColor Cyan
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
New-Item -ItemType Directory -Path $Destination
}

# Push-Location $Destination

If (!(Test-Path -Path $Source))
{
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Destination\$Source
Write-Host "$Vendor $Product download finished" -ForegroundColor Cyan
Write-Host ""
}

# Pop-Location

# Deploy Microsoft Edge
Start-Process -FilePath $Destination\$Source -Wait -ArgumentList $InstallArguments

# Microsoft Edge post deployment tasks
# Disable Microsoft Edge scheduled tasks

# Disable Microsoft Edge update service
$Services = "edgeupdate","MicrosoftEdgeElevationService"
ForEach ($Service in $Services)
{
If ((Get-Service -Name $Service).Status -eq "Stopped")
{
Set-Service -Name $Service -StartupType Disabled
}
else
{
Stop-Service -Name $Service -Force -Verbose
Set-Service -Name $Service -StartupType Disabled
}
}