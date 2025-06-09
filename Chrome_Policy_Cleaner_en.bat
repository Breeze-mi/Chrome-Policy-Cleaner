@echo off
setlocal EnableDelayedExpansion

:: =============================================================
:: Check for administrator privileges and auto-elevate if needed
:: =============================================================
if /I "%~1" neq "ELEV" (
    net session >nul 2>&1
    if errorlevel 1 (
        echo [!] This script requires administrator privileges. Attempting to relaunch as admin...
        ping 127.0.0.1 -n 5 >nul
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList 'ELEV' -Verb runAs"
        exit /b
    )
)

if /I "%~1"=="ELEV" (
    echo ================================================
    echo     Running as administrator (ELEV mode)
    echo ================================================
) else (
    echo ================================================
    echo     Running with admin privileges
    echo ================================================
)
echo.
timeout /t 1 /nobreak >nul

:: =================== Define path variables ===================
set "ChromePath=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
set "EdgePath=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
set "SYS32=%SystemRoot%\System32"
set "TASKKILL=%SYS32%\taskkill.exe"
set "GPUPDATE=%SYS32%\gpupdate.exe"
set "REG=%SYS32%\reg.exe"
rem rd is a built-in CMD command without external executable files
set "TAKEOWN=%SYS32%\takeown.exe"
set "ICACLS=%SYS32%\icacls.exe"
set "EXPLORER=%SystemRoot%\explorer.exe"

:: =================== 1/9 Kill browser processes ===================
echo [1/9] Closing Chrome and Edge browser processes...
"%TASKKILL%" /F /IM chrome.exe /T >nul 2>&1
"%TASKKILL%" /F /IM msedge.exe /T >nul 2>&1
echo        All related processes attempted to be terminated
echo.
timeout /t 1 /nobreak >nul

:: =================== 2/9 Delete policy folders ===================
echo [2/9] Deleting policy folders...
for %%D in (
    "%WINDIR%\System32\GroupPolicy"
    "%WINDIR%\System32\GroupPolicyUsers"
    "%ProgramFiles%\Google\Policies"
    "%ProgramFiles(x86)%\Google\Policies"
    "%ProgramFiles%\Chromium\Policies"
    "%ProgramFiles(x86)%\Chromium\Policies"
) do (
    if exist "%%~D" (
        echo   Deleting: %%~D
        rd /s /q "%%~D"
    ) else (
        echo   Not found: %%~D, skipping.
    )
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 3/9 Force group policy refresh ===================
echo [3/9] Forcing group policy update...
"%GPUPDATE%" /force >nul
echo.
timeout /t 1 /nobreak >nul

:: =================== 4/9 Delete registry policy keys ===================
echo [4/9] Deleting policy-related registry keys...
for %%K in (
    "HKLM\Software\Policies\Google\Chrome"
    "HKLM\Software\Policies\Google\Update"
    "HKLM\Software\Policies\Chromium"
    "HKLM\Software\Google\Chrome"
    "HKLM\Software\WOW6432Node\Google\Enrollment"
    "HKCU\Software\Policies\Google\Chrome"
    "HKCU\Software\Policies\Google\Update"
    "HKCU\Software\Policies\Chromium"
    "HKCU\Software\Google\Chrome"
) do (
    "%REG%" delete %%~K /f >nul 2>&1
    if errorlevel 1 (
        echo   [Skip] Not found or cannot delete: %%~K
    ) else (
        echo   [Deleted] %%~K
    )
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 5/9 Delete common registry values ===================
echo [5/9] Deleting specific policy values...
for %%V in (
    "HKLM\Software\Policies\Google\Update\AutoUpdateCheckPeriodMinutes"
    "HKLM\Software\Policies\Google\Update\UpdateDefault"
    "HKLM\Software\Policies\Chromium\AutoUpdateCheckPeriodMinutes"
) do (
    "%REG%" delete %%~V /f >nul 2>&1
    if errorlevel 1 (
        echo   [Skip] Not found or cannot delete: %%~V
    ) else (
        echo   [Deleted] %%~V
    )
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 6/9 Delete CloudManagementEnrollmentToken ===================
echo [6/9] Deleting CloudManagementEnrollmentToken...
set "CMRegKey=HKLM\Software\WOW6432Node\Google\Update\ClientState\{430FD4D0-B729-4F61-AA34-91526481799D}"
set "CMRegVal=CloudManagementEnrollmentToken"
reg query "%CMRegKey%" /v "%CMRegVal%" >nul 2>&1
if errorlevel 1 (
    echo   Token not found, skipping.
) else (
    "%REG%" delete "%CMRegKey%" /v "%CMRegVal%" /f >nul
    echo   [Deleted] CloudManagementEnrollmentToken
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 7/9 Restart Explorer ===================
echo [7/9] Restarting Windows Explorer...
if exist "%EXPLORER%" (
    "%TASKKILL%" /F /IM explorer.exe >nul 2>&1
    start "" "%EXPLORER%"
    echo   Explorer restarted successfully.
) else (
    echo   [Error] Explorer not found at: %EXPLORER%
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 8/9 Remind user to check policies ===================
echo [8/9] Manually check the browser policies by visiting:
echo   chrome://policy
echo   edge://policy
echo.
timeout /t 1 /nobreak >nul

:: =================== 9/9 Done ===================
echo [9/9] All tasks completed!
echo It's recommended to restart your PC to ensure all changes take full effect.
echo Press Enter to exit or close this window manually.
pause
cmd /k
