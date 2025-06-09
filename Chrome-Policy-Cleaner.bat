@echo off
setlocal EnableDelayedExpansion

:: =============================================================
:: 管理员权限检测与自提升（避免死循环，并加入2秒延时提示）
:: =============================================================
if /I "%~1" neq "ELEV" (
    net session >nul 2>&1
    if errorlevel 1 (
        echo [!] 本脚本需要以管理员权限运行，正在尝试重新启动...
        ping 127.0.0.1 -n 5 >nul
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList 'ELEV' -Verb runAs"
        exit /b
    )
)

if /I "%~1"=="ELEV" (
    echo ================================================
    echo     带 ELEV 参数的管理员身份运行模式
    echo ================================================
) else (
    echo ================================================
    echo     成功使用管理员权限运行（不带 ELEV 参数的管理员启动模式）
    echo ================================================
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 定义路径变量 ===================
set "ChromePath=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
set "EdgePath=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
set "SYS32=%SystemRoot%\System32"
set "TASKKILL=%SYS32%\taskkill.exe"
set "GPUPDATE=%SYS32%\gpupdate.exe"
set "REG=%SYS32%\reg.exe"
rem rd 是 CMD 内置命令，无需外部可执行文件,所以前面这里报错就删了
set "TAKEOWN=%SYS32%\takeown.exe"
set "ICACLS=%SYS32%\icacls.exe"
set "EXPLORER=%SystemRoot%\explorer.exe"

:: =================== 1/9 关闭浏览器进程 ===================
echo [1/9] 关闭 Chrome 和 Edge 浏览器进程...
"%TASKKILL%" /F /IM chrome.exe /T >nul 2>&1
"%TASKKILL%" /F /IM msedge.exe /T >nul 2>&1
echo        所有相关进程已尝试终止
echo.
timeout /t 1 /nobreak >nul

:: =================== 2/9 删除本地策略文件夹 ===================
echo [2/9] 删除策略文件夹...
for %%D in (
    "%WINDIR%\System32\GroupPolicy"
    "%WINDIR%\System32\GroupPolicyUsers"
    "%ProgramFiles%\Google\Policies"
    "%ProgramFiles(x86)%\Google\Policies"
    "%ProgramFiles%\Chromium\Policies"
    "%ProgramFiles(x86)%\Chromium\Policies"
) do (
    if exist "%%~D" (
        echo   正在删除：%%~D
        rd /s /q "%%~D"
    ) else (
        echo   未发现：%%~D，跳过。
    )
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 3/9 强制刷新本地组策略 ===================
echo [3/9] 强制刷新组策略...
"%GPUPDATE%" /force >nul
echo.
timeout /t 1 /nobreak >nul

:: =================== 4/9 删除策略注册表键 ===================
echo [4/9] 删除策略注册表键...
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
        echo   [跳过] 未找到或无法删除：%%~K
    ) else (
        echo   [已删除] %%~K
    )
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 5/9 删除常见策略值 ===================
echo [5/9] 删除策略值...
for %%V in (
    "HKLM\Software\Policies\Google\Update\AutoUpdateCheckPeriodMinutes"
    "HKLM\Software\Policies\Google\Update\UpdateDefault"
    "HKLM\Software\Policies\Chromium\AutoUpdateCheckPeriodMinutes"
) do (
    "%REG%" delete %%~V /f >nul 2>&1
    if errorlevel 1 (
        echo   [跳过] 未发现或无法删除：%%~V
    ) else (
        echo   [已删除] %%~V
    )
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 6/9 删除 CloudManagementEnrollmentToken ===================
echo [6/9] 删除 CloudManagementEnrollmentToken...
set "CMRegKey=HKLM\Software\WOW6432Node\Google\Update\ClientState\{430FD4D0-B729-4F61-AA34-91526481799D}"
set "CMRegVal=CloudManagementEnrollmentToken"
reg query "%CMRegKey%" /v "%CMRegVal%" >nul 2>&1
if errorlevel 1 (
    echo   未检测到 CloudManagementEnrollmentToken，跳过。
) else (
    "%REG%" delete "%CMRegKey%" /v "%CMRegVal%" /f >nul
    echo   [已删除] CloudManagementEnrollmentToken
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 7/9 重启资源管理器 Explorer ===================
echo [7/9] 重启资源管理器 Explorer...
if exist "%EXPLORER%" (
    "%TASKKILL%" /F /IM explorer.exe >nul 2>&1
    start "" "%EXPLORER%"
    echo   Explorer 已重启。
) else (
    echo   [错误] 未找到 Explorer：%EXPLORER%
)
echo.
timeout /t 1 /nobreak >nul

:: =================== 8/9 提示用户检查策略页面 ===================
echo [8/9] 请手动在浏览器地址栏输入以下地址检查策略：
echo   chrome://policy
echo   edge://policy
echo.
timeout /t 1 /nobreak >nul

:: =================== 9/9 操作完成 ===================
echo [9/9] 所有操作已完成！
echo 建议重启计算机以确保策略完全清除。
echo  请手动关闭此窗口或按回车退出。
pause
cmd /k
