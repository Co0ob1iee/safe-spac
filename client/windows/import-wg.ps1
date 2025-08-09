# Imports a WireGuard profile located as admin-wg.conf in the same directory
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$conf = Join-Path $scriptDir 'admin-wg.conf'
if (Test-Path $conf) {
  & "C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice $conf
}
