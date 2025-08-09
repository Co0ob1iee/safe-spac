; Inno Setup script for SafeSpac Windows installer (placeholder)
#define MyAppName "SafeSpac"
#define MyAppVersion "0.0.1"
#define MyAppPublisher "SafeSpac"
#define MyAppExeName "SafeSpac.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-47F8-90AB-1234567890AB}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=.
OutputBaseFilename=SafeSpac-Setup
Compression=lzma
SolidCompression=yes

[Files]
; Install application placeholder binary (none for now)
; Install admin-wg.conf if present next to installer
Source: "admin-wg.conf"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Run]
; Import WireGuard profile if admin-wg.conf present
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File \"{app}\\import-wg.ps1\""; WorkingDir: "{app}"; Flags: skipifsilent runhidden; Check: FileExists(ExpandConstant('{app}\\admin-wg.conf'))

[Code]
function FileExists(const FileName: string): Boolean;
var
  FindRec: TFindRec;
begin
  Result := FindFirst(FileName, FindRec);
  FindClose(FindRec);
end;
