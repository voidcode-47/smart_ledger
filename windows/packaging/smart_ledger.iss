; 智慧记账 — Inno Setup 安装包脚本
; 使用方法：
;   1. 先构建 Release 版本：flutter build windows --release
;   2. 安装 Inno Setup 6（https://jrsoftware.org/isinfo.php）
;   3. 在项目根目录执行：iscc windows\packaging\smart_ledger.iss
;   4. 生成的单文件安装包位于项目根目录的 dist\ 文件夹

#define MyAppName "智慧记账"
#define MyAppVersion "1.0.0"
#define MyAppExeName "smart_ledger.exe"
; 脚本位于 windows\packaging\，..\..\ 即项目根目录
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
; 注意：AppId 的值需保持稳定（唯一标识本应用，升级覆盖安装靠它识别），不要随意修改
AppId={{5F2B6E8A-3D4C-4A1E-9C7B-2E8F0D6A4B31}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppName}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; 安装包与卸载项均使用 Flutter Windows runner 自带的应用图标
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\..\dist
OutputBaseFilename=smart_ledger_setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; 记账数据存放于用户 AppData（与安装目录无关），应用本身无需写受保护目录，
; 按用户安装可免 UAC 弹窗；如需安装到 Program Files 可删除本行
PrivilegesRequired=lowest

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 必须整目录打包：Flutter 的 data\ 文件夹与全部 DLL 需与 EXE 放在一起，
; recursesubdirs createallsubdirs 已覆盖
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 注：不勾选 uninsneveruninstall；卸载不会触碰 AppData 中的记账数据，数据安全

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
