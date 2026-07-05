@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%sshkeysetup.ps1"

if not exist "%PS_SCRIPT%" (
    echo ERROR: Cannot find "%PS_SCRIPT%".
    pause
    exit /b 1
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: powershell.exe was not found.
    pause
    exit /b 1
)

if "%~1"=="" (
    echo sshkeysetup Windows launcher
    echo.
    set /p "TARGET=Enter remote target as user@host: "
    if "%TARGET%"=="" (
        echo ERROR: No target entered.
        pause
        exit /b 1
    )
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" "%TARGET%" -AcceptNewHostKey
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
)

set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" pause
exit /b %EXIT_CODE%
