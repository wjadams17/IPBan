Windows Installer (Run from Administrator PowerShell):
$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/wjadams17/IPBan/releases/latest/download/official_install.ps1'))
