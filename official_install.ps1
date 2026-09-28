# IPBan installer with custom configuration
#
# Run this script from an elevated (administrator) PowerShell prompt.
#
# This script:
#   1. Downloads the official IPBan installer
#   2. Installs/updates IPBan without starting the service
#   3. Downloads a custom ipban.config from GitHub
#   4. Backs up the installed configuration
#   5. Replaces it with the custom configuration
#   6. Starts the IPBan service

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --------------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------------

$InstallerUrl = "https://raw.githubusercontent.com/DigitalRuby/IPBan/master/IPBanCore/Windows/Scripts/install_latest.ps1"

#GitHub raw ipban.config URL
$ConfigUrl = "https://raw.githubusercontent.com/wjadams17/IPBan/main/ipban.config"

$InstallPath = "C:\Program Files\IPBan"
$ConfigFile = Join-Path $InstallPath "ipban.config"
$BackupFile = Join-Path $InstallPath "ipban.config.backup"

$ServiceName = "IPBan"

# --------------------------------------------------------------------
# REQUIRE ADMINISTRATOR
# --------------------------------------------------------------------

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Error "This script must be run as Administrator."
    exit 1
}

# --------------------------------------------------------------------
# FORCE TLS 1.2
# --------------------------------------------------------------------

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --------------------------------------------------------------------
# DOWNLOAD OFFICIAL IPBAN INSTALLER
# --------------------------------------------------------------------

$tempInstaller = Join-Path $env:TEMP "install_latest_ipban.ps1"

Write-Output "Downloading official IPBan installer..."
Invoke-WebRequest `
    -Uri $InstallerUrl `
    -OutFile $tempInstaller

# --------------------------------------------------------------------
# RUN IPBAN INSTALLER
#
# -silent $true
# -autostart $false
#
# This allows us to install/update IPBan without starting it
# before our custom configuration is installed.
# --------------------------------------------------------------------

Write-Output "Installing/updating IPBan..."

& $tempInstaller `
    -silent $true `
    -autostart $false

if ($LASTEXITCODE -ne 0)
{
    throw "IPBan installer returned exit code $LASTEXITCODE"
}

# --------------------------------------------------------------------
# VERIFY INSTALLATION
# --------------------------------------------------------------------

if (-not (Test-Path $InstallPath))
{
    throw "IPBan installation directory was not found: $InstallPath"
}

# --------------------------------------------------------------------
# DOWNLOAD CUSTOM CONFIGURATION
# --------------------------------------------------------------------

$tempConfig = Join-Path $env:TEMP "ipban-custom.config"

Write-Output "Downloading custom IPBan configuration..."
Write-Output "Source: $ConfigUrl"

Invoke-WebRequest `
    -Uri $ConfigUrl `
    -OutFile $tempConfig

if (-not (Test-Path $tempConfig))
{
    throw "Failed to download custom IPBan configuration."
}

# --------------------------------------------------------------------
# BASIC XML VALIDATION
#
# This prevents replacing the working configuration with something
# that isn't valid XML.
# --------------------------------------------------------------------

Write-Output "Validating custom configuration..."

try
{
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($tempConfig)
}
catch
{
    Remove-Item $tempConfig -Force -ErrorAction SilentlyContinue
    throw "The downloaded ipban.config is not valid XML. Existing configuration was not changed."
}

# --------------------------------------------------------------------
# BACK UP CURRENT CONFIGURATION
# --------------------------------------------------------------------

if (Test-Path $ConfigFile)
{
    Write-Output "Backing up current IPBan configuration..."

    Copy-Item `
        -Path $ConfigFile `
        -Destination $BackupFile `
        -Force
}

# --------------------------------------------------------------------
# REPLACE CONFIGURATION
# --------------------------------------------------------------------

Write-Output "Installing custom IPBan configuration..."

Copy-Item `
    -Path $tempConfig `
    -Destination $ConfigFile `
    -Force

Remove-Item $tempConfig -Force -ErrorAction SilentlyContinue

# --------------------------------------------------------------------
# VERIFY NEW CONFIGURATION
# --------------------------------------------------------------------

if (-not (Test-Path $ConfigFile))
{
    throw "The new IPBan configuration was not installed."
}

Write-Output "Custom IPBan configuration installed successfully."

# --------------------------------------------------------------------
# START IPBAN
# --------------------------------------------------------------------

Write-Output "Starting IPBan service..."

Start-Service -Name $ServiceName

# --------------------------------------------------------------------
# VERIFY SERVICE
# --------------------------------------------------------------------

$service = Get-Service -Name $ServiceName

if ($service.Status -ne "Running")
{
    Write-Warning "IPBan service is not running. Current status: $($service.Status)"
    Write-Warning "The previous configuration is available at:"
    Write-Warning $BackupFile
}
else
{
    Write-Output "IPBan service is running."
}

# --------------------------------------------------------------------
# CLEAN UP
# --------------------------------------------------------------------

Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "=============================================="
Write-Output "IPBan installation/update complete."
Write-Output "Configuration: $ConfigFile"
Write-Output "Backup:        $BackupFile"
Write-Output "=============================================="

Write-Host ""
Write-Host "IPBan installation complete." -ForegroundColor Green
Write-Host "The window will close in 10 seconds."
Write-Host "Press C to cancel and keep this window open."

for ($i = 10; $i -gt 0; $i--) {
    Write-Host "`rClosing in $i seconds... " -NoNewline

    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)

        if ($key.Key -eq "C") {
            Write-Host ""
            Write-Host "Auto-close cancelled."
            break
        }
    }

    Start-Sleep -Seconds 1
}

if ($key.Key -ne "C") {
    exit
}
