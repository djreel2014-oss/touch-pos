@echo off
setlocal
rem Touch POS launcher. "Start-TouchPOS.cmd kiosk" starts full screen. Reads the monitor chosen in Settings.
set "APP=%~dp0app\index.html"
set "APPURL=file:///%APP:\=/%"
set "DATA=%ProgramData%\TouchPOS\Profile"
if not exist "%ProgramData%\TouchPOS" set "DATA=%~dp0Data\Profile"
set "FILES=%ProgramData%\TouchPOS\Files"
set "BR="
for %%P in ("%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" "%ProgramW6432%\Microsoft\Edge\Application\msedge.exe" "%LocalAppData%\Microsoft\Edge\Application\msedge.exe" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" "%ProgramW6432%\Google\Chrome\Application\chrome.exe" "%LocalAppData%\Google\Chrome\Application\chrome.exe") do if not defined BR if exist "%%~P" set "BR=%%~P"
if not defined BR (
  echo Touch POS needs the Microsoft Edge or Google Chrome engine that comes with Windows 10 and 11, and neither was found.
  pause
  exit /b 1
)
set "MODE=--start-maximized"
set "HASH="
if /i "%~1"=="kiosk" (set "MODE=--start-fullscreen" & set "HASH=#kiosk")
set "MFILE="
for /f "usebackq delims=" %%F in (`dir /b /o-d "%FILES%\monitor*.cfg" 2^>nul`) do if not defined MFILE set "MFILE=%%F"
if defined MFILE for /f "usebackq tokens=1-4 delims=," %%a in ("%FILES%\%MFILE%") do (
  if /i "%~1"=="kiosk" (set "MODE=--window-position=%%a,%%b --window-size=%%c,%%d --start-fullscreen") else (set "MODE=--window-position=%%a,%%b --window-size=%%c,%%d")
)
start "" "%BR%" --app="%APPURL%%HASH%" --user-data-dir="%DATA%" --no-first-run --disable-features=Translate %MODE%
