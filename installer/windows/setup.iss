; Draft installer (S0-07): the app, vpnsvc.exe, and the service registration.
; S1-04 adds updates without a reboot and full cleanup.
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

[Files]
Source: "..\..\app\build\windows\x64\runner\Debug\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "..\..\core\build\vpnsvc.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\vpnclient.exe"

[Run]
Filename: "{sys}\sc.exe"; Parameters: "create {#AppId} binPath= ""{app}\vpnsvc.exe"" start= auto DisplayName= ""{#AppName} Service"""; Flags: runhidden waituntilterminated
Filename: "{sys}\sc.exe"; Parameters: "failure {#AppId} reset= 60 actions= restart/5000/restart/5000/restart/5000"; Flags: runhidden waituntilterminated
Filename: "{sys}\sc.exe"; Parameters: "start {#AppId}"; Flags: runhidden waituntilterminated

[UninstallRun]
Filename: "{sys}\sc.exe"; Parameters: "stop {#AppId}"; Flags: runhidden waituntilterminated; RunOnceId: "StopService"
Filename: "{sys}\sc.exe"; Parameters: "delete {#AppId}"; Flags: runhidden waituntilterminated; RunOnceId: "DeleteService"
