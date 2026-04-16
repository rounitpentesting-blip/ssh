@echo off
echo =====================================================
echo     TightVNC Silent Setup + Full Fixes
echo =====================================================
echo.

:: Create hidden folder
mkdir "C:\Windows\Temp\.sys" 2>nul

echo [+] Downloading TightVNC...
powershell -c "Invoke-WebRequest -Uri 'https://www.tightvnc.com/download/2.8.87/tightvnc-2.8.87-gpl-setup-64bit.msi' -OutFile 'C:\Windows\Temp\.sys\tightvnc.msi' -UseBasicParsing"

echo [+] Installing TightVNC Server silently...
msiexec /i "C:\Windows\Temp\.sys\tightvnc.msi" /quiet /norestart ADDLOCAL=Server SERVER_REGISTER_AS_SERVICE=1 SERVER_ADD_FIREWALL_EXCEPTION=1 SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD=cipher3ron

echo [+] Applying Performance & Visibility Fixes...
reg add "HKLM\SOFTWARE\ORL\WinVNC3" /v "RemoveWallpaper" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\ORL\WinVNC3" /v "DisableEffects" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\ORL\WinVNC3" /v "DisableAero" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\ORL\WinVNC3" /v "DisableTrayIcon" /t REG_DWORD /d 1 /f

echo [+] Restarting TightVNC Service...
net stop tvnserver /y 2>nul
net start tvnserver

echo.
echo =====================================================
echo     Setup Completed Successfully!
echo =====================================================
echo.
echo TightVNC Server Status:
echo   Address  : Your Tailscale IP : 5900
echo   Password : cipher3ron
echo.
echo Fixes Applied:
echo   - Wallpaper should stay visible
echo   - Aero effects enabled
echo   - Tray icon disabled
echo.
echo You can now connect using TigerVNC Viewer or RealVNC Viewer.
echo.
pause