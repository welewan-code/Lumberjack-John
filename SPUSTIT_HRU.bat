@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Lumberjack John - aktualizace a spusteni

echo ========================================
echo   LUMBERJACK JOHN - JEDEN KLIK
echo ========================================
echo.

rem --- Najdi Git ---
set "GIT_EXE="
for %%G in (git.exe) do where %%G >nul 2>nul && set "GIT_EXE=%%G"
if not defined GIT_EXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GIT_EXE if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT_EXE=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"

rem --- Kdyz Git chybi, zkus ho nainstalovat automaticky pres winget ---
if not defined GIT_EXE (
  echo Git chybi - instaluji automaticky...
  where winget >nul 2>nul
  if errorlevel 1 goto :no_winget
  winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
  if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles%\Git\cmd\git.exe"
  if not defined GIT_EXE if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT_EXE=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"
)

rem --- Stahni posledni moje zmeny z GitHubu ---
if defined GIT_EXE if exist ".git" (
  echo.
  echo Stahuji posledni verzi hry...
  "%GIT_EXE%" pull --ff-only
)

rem --- Najdi Godot ---
call :find_godot

rem --- Kdyz Godot chybi, nainstaluj ho automaticky ---
if not defined GODOT_EXE (
  echo.
  echo Godot chybi - instaluji automaticky...
  where winget >nul 2>nul
  if errorlevel 1 goto :no_winget
  winget install --id GodotEngine.GodotEngine -e --source winget --silent --accept-package-agreements --accept-source-agreements
  call :find_godot
)

if not defined GODOT_EXE goto :godot_failed

rem --- Spust projekt rovnou v Godotu ---
echo.
echo Spoustim Lumberjack John v Godotu...
start "" "%GODOT_EXE%" --editor --path "%~dp0"
exit /b 0

:find_godot
set "GODOT_EXE="
where godot.exe >nul 2>nul && set "GODOT_EXE=godot.exe"
if not defined GODOT_EXE where godot4.exe >nul 2>nul && set "GODOT_EXE=godot4.exe"
if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Programs\Godot\Godot.exe" set "GODOT_EXE=%LOCALAPPDATA%\Programs\Godot\Godot.exe"
if not defined GODOT_EXE if exist "%ProgramFiles%\Godot\Godot.exe" set "GODOT_EXE=%ProgramFiles%\Godot\Godot.exe"
if not defined GODOT_EXE (
  for /f "delims=" %%G in ('dir /b /s "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*\Godot*.exe" 2^>nul ^| findstr /vi "_console"') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
exit /b

:no_winget
echo.
echo Windows nema prikaz winget. Otevri Microsoft Store a nainstaluj nebo aktualizuj "App Installer".
echo Potom tenhle soubor spust znovu.
pause
exit /b 1

:godot_failed
echo.
echo Godot se nepodarilo automaticky najit nebo nainstalovat.
echo Zkus znovu spustit tento soubor, pripadne mi posli fotku teto obrazovky.
pause
exit /b 1
