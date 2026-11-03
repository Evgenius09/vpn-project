; The app, vpnsvc.exe, and the service registration (tech.md 5.6, S1-04).
; An update needs no reboot, and removal leaves no service, adapter, or secrets.
#define AppId "vpnclient"
#define AppName "VPN Client"
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename=vpnclient-setup
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
Compression=lzma2
SolidCompression=yes
UninstallDisplayName={#AppName}
CloseApplications=force
RestartApplications=no

[Files]
Source: "..\..\app\build\windows\x64\runner\Debug\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "..\..\core\build\vpnsvc.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\vpnclient.exe"

[Run]
; On an update the service exists already, and sc only reports that.
Filename: "{sys}\sc.exe"; Parameters: "create {#AppId} binPath= ""{app}\vpnsvc.exe"" start= auto DisplayName= ""{#AppName} Service"""; Flags: runhidden waituntilterminated
Filename: "{sys}\sc.exe"; Parameters: "failure {#AppId} reset= 60 actions= restart/5000/restart/5000/restart/5000"; Flags: runhidden waituntilterminated
Filename: "{sys}\sc.exe"; Parameters: "start {#AppId}"; Flags: runhidden waituntilterminated

[UninstallRun]
; net stop waits for the service, so vpnsvc.exe is free to delete.
Filename: "{sys}\net.exe"; Parameters: "stop {#AppId}"; Flags: runhidden waituntilterminated; RunOnceId: "StopService"
Filename: "{sys}\sc.exe"; Parameters: "delete {#AppId}"; Flags: runhidden waituntilterminated; RunOnceId: "DeleteService"
; The service closes its adapter, so only a crash leaves one. A working adapter
; can belong to another sing-box app and stays.
Filename: "powershell.exe"; Parameters: "-NoProfile -NonInteractive -Command ""Get-PnpDevice -Class Net -ErrorAction SilentlyContinue | Where-Object {{ $_.FriendlyName -like 'sing-tun*' -and $_.Status -ne 'OK' } | ForEach-Object {{ pnputil /remove-device $_.InstanceId }"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveAdapter"

[UninstallDelete]
; last_request.json holds server secrets.
Type: filesandordirs; Name: "{commonappdata}\{#AppId}"

[Code]
// A running service locks vpnsvc.exe, and replacing it would need a reboot.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\net.exe'), 'stop {#AppId}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := '';
end;
