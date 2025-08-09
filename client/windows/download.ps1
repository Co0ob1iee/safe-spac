# Downloads and installs WireGuard (silent) and optionally TeamSpeak 6 (manual)
# Run as Administrator

$ErrorActionPreference = 'Stop'

# WireGuard
$wgUrl = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
$wgExe = "$env:TEMP\wireguard-installer.exe"
Write-Host "Downloading WireGuard..."
Invoke-WebRequest -Uri $wgUrl -OutFile $wgExe
Write-Host "Installing WireGuard silently..."
Start-Process -FilePath $wgExe -ArgumentList "/S" -Wait -PassThru | Out-Null

# Import admin-wg.conf if present next to this script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$conf = Join-Path $scriptDir 'admin-wg.conf'
if (Test-Path $conf) {
  Write-Host "Importing admin-wg.conf into WireGuard..."
  & "C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice $conf
}

Write-Host "Done."
