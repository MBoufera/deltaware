; installer.nsi
; NSIS Script for Deltaware Flutter Desktop Application

; Include Modern UI
!include "MUI2.nsh"

; General Definitions
!define APPNAME "deltaware"
!define COMPANYNAME "Deltaware"
!define DESCRIPTION "Deltaware Windows Desktop Application"
!define VERSIONMAJOR 1
!define VERSIONMINOR 0
!define VERSIONBUILD 0

Name "${APPNAME}"
OutFile "AppSetup.exe"
InstallDir "$PROGRAMFILES64\${COMPANYNAME}\${APPNAME}"

; Request administrative privileges
RequestExecutionLevel admin

; UI Settings
!define MUI_ABORTWARNING

; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Languages
!insertmacro MUI_LANGUAGE "English"

; Install Section
Section "Install"
    ; Set output path to the installation directory
    SetOutPath "$INSTDIR"
    
    ; Copy all built files recursively from the build output directory.
    ; Since this script is located in the 'windows' directory, we use the relative path
    ; '..\build\windows\x64\runner\Release\*.*' to grab files from the build output.
    File /r "..\build\windows\x64\runner\Release\*.*"
    
    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; Create Start Menu Shortcuts
    CreateDirectory "$SMPROGRAMS\${COMPANYNAME}"
    CreateShortcut "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk" "$INSTDIR\${APPNAME}.exe" "" "$INSTDIR\${APPNAME}.exe" 0
    CreateShortcut "$SMPROGRAMS\${COMPANYNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
    
    ; Create Desktop Shortcut
    CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${APPNAME}.exe" "" "$INSTDIR\${APPNAME}.exe" 0
    
    ; Registry keys for Windows Add/Remove Programs (Uninstaller)
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayName" "${APPNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayIcon" '"$INSTDIR\${APPNAME}.exe"'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "Publisher" "${COMPANYNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayVersion" "${VERSIONMAJOR}.${VERSIONMINOR}.${VERSIONBUILD}"
    
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "NoRepair" 1
SectionEnd

; Uninstall Section
Section "Uninstall"
    ; Remove shortcuts
    Delete "$DESKTOP\${APPNAME}.lnk"
    Delete "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk"
    Delete "$SMPROGRAMS\${COMPANYNAME}\Uninstall ${APPNAME}.lnk"
    RMDir "$SMPROGRAMS\${COMPANYNAME}"
    
    ; Remove registry keys
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
    
    ; We delete the files that we installed.
    ; Note: RMDir /r is recursive, so it cleans up all subdirectories and files.
    RMDir /r "$INSTDIR"
    
    ; Clean up parent company folder if empty
    RMDir "$PROGRAMFILES64\${COMPANYNAME}"
SectionEnd
