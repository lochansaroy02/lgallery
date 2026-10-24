; Inno Setup script for the LGallery Windows installer (used by packaging/windows/build.ps1).
;
;   iscc /DAppVersion=0.3.0 packaging\windows\lgallery.iss
;
; Packs dist\LGallery (the PyInstaller build) into dist\LGallery-<version>-setup.exe.
; Installs for the current user without admin rights by default; the first page offers
; "Install for all users" (needs admin). Registers LGallery in "Open with" and in
; Settings > Apps > Default apps for pictures and videos.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "LGallery"
#define AppExe "LGallery.exe"
#define AppURL "https://github.com/lochansaroy02/lgallery"

[Setup]
AppId={{6F1C2B7E-4A8D-4D6B-9E3A-5C2F1E8B7A90}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=LGallery
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
LicenseFile=..\..\LICENSE
SetupIconFile=lgallery.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\..\dist
OutputBaseFilename={#AppName}-{#AppVersion}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
CloseApplications=yes
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} installer

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "assoc"; Description: "Add LGallery to ""Open with"" and Default apps for pictures and videos"; GroupDescription: "Integration:"

[Files]
Source: "..\..\dist\LGallery\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; Comment: "Photo and video gallery"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; file types LGallery can open ("LGallery picture" / "LGallery video")
Root: HKA; Subkey: "Software\Classes\LGallery.Image"; ValueType: string; ValueData: "LGallery picture"; Flags: uninsdeletekey; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\LGallery.Image\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExe},0"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\LGallery.Image\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\LGallery.Video"; ValueType: string; ValueData: "LGallery video"; Flags: uninsdeletekey; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\LGallery.Video\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExe},0"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\LGallery.Video\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: assoc
; the application itself ("Open with" list)
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: assoc
; Settings > Apps > Default apps
Root: HKA; Subkey: "Software\LGallery"; Flags: uninsdeletekey; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#AppName}"; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "One UI style photo and video gallery"; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: "{app}\{#AppExe},0"; Tasks: assoc
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "LGallery"; ValueData: "Software\LGallery\Capabilities"; Flags: uninsdeletevalue; Tasks: assoc
; extensions
Root: HKA; Subkey: "Software\Classes\.jpg\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".jpg"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".jpg"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.jpeg\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".jpeg"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".jpeg"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.png\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".png"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".png"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.webp\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".webp"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".webp"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.gif\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".gif"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".gif"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.bmp\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".bmp"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".bmp"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.tif\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".tif"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".tif"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.tiff\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".tiff"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".tiff"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.heic\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".heic"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".heic"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.heif\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Image"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".heif"; ValueData: "LGallery.Image"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".heif"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.mp4\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mp4"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".mp4"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.m4v\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m4v"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".m4v"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.mov\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mov"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".mov"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.mkv\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mkv"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".mkv"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.webm\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".webm"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".webm"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.avi\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".avi"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".avi"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.3gp\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".3gp"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".3gp"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.mts\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mts"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".mts"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.m2ts\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m2ts"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".m2ts"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.wmv\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wmv"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".wmv"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.ogv\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ogv"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".ogv"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.mpg\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mpg"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".mpg"; ValueData: ""; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.mpeg\OpenWithProgids"; ValueType: string; ValueName: "LGallery.Video"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\LGallery\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mpeg"; ValueData: "LGallery.Video"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\Applications\LGallery.exe\SupportedTypes"; ValueType: string; ValueName: ".mpeg"; ValueData: ""; Tasks: assoc

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Python bytecode written next to the program, if any
Type: filesandordirs; Name: "{app}\_internal\__pycache__"
