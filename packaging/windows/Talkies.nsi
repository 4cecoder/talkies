Unicode true
RequestExecutionLevel user
SetCompressor /SOLID zlib

!include "MUI2.nsh"

!ifndef APP_VERSION
  !error "APP_VERSION must be provided"
!endif
!ifndef PUBLISH_DIRECTORY
  !error "PUBLISH_DIRECTORY must be provided"
!endif
!ifndef OUTPUT_PATH
  !error "OUTPUT_PATH must be provided"
!endif
!ifndef REPOSITORY_ROOT
  !error "REPOSITORY_ROOT must be provided"
!endif

Name "Talkies ${APP_VERSION}"
OutFile "${OUTPUT_PATH}"
InstallDir "$LOCALAPPDATA\Programs\Talkies"
InstallDirRegKey HKCU "Software\Talkies" "InstallLocation"
ShowInstDetails show
ShowUnInstDetails show
Var StartMenuFolder
Icon "${PUBLISH_DIRECTORY}\Resources\talkies-app-icon.ico"
UninstallIcon "${PUBLISH_DIRECTORY}\Resources\talkies-app-icon.ico"

!define MUI_ABORTWARNING
!define MUI_LICENSEPAGE_TEXT_TOP "Talkies is free software distributed under the MIT License."
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "Talkies"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT HKCU
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\Talkies"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "StartMenuFolder"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${REPOSITORY_ROOT}\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  SetShellVarContext current
FunctionEnd

Function un.onInit
  SetShellVarContext current
FunctionEnd

Section "Talkies application" SecApplication
  ; Replace the app-only install tree completely so removed files don't linger
  ; after upgrades. Preferences and model files are stored outside this folder.
  RMDir /r "$INSTDIR"
  CreateDirectory "$INSTDIR"
  SetOutPath "$INSTDIR"
  File /r "${PUBLISH_DIRECTORY}\*"
  File "${REPOSITORY_ROOT}\packaging\windows\THIRD-PARTY-NOTICES.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Talkies" "InstallLocation" "$INSTDIR"

  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Talkies.lnk" "$INSTDIR\Talkies.Windows.exe" "" "$INSTDIR\Resources\talkies-app-icon.ico"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Uninstall Talkies.lnk" "$INSTDIR\Uninstall.exe"
  !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

Section "Uninstall"
  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  Delete "$SMPROGRAMS\$StartMenuFolder\Talkies.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall Talkies.lnk"
  RMDir "$SMPROGRAMS\$StartMenuFolder"
  DeleteRegKey HKCU "Software\Talkies"
  ; The install directory contains only application files. User settings and
  ; model weights live in %USERPROFILE%\.talkies and %LOCALAPPDATA%\Talkies\Models.
  RMDir /r "$INSTDIR"
SectionEnd
