@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Lumberjack John - hra

set "GIT_EXE="
where git.exe >nul 2>nul && set "GIT_EXE=git.exe"
if not defined GIT_EXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GIT_EXE if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT_EXE=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"

if defined GIT_EXE if exist ".git" (
  echo Stahuji posledni verzi...
  "%GIT_EXE%" pull --ff-only
)

set "GODOT_EXE="
where godot.exe >nul 2>nul && set "GODOT_EXE=godot.exe"
if not defined GODOT_EXE where godot4.exe >nul 2>nul && set "GODOT_EXE=godot4.exe"
if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Programs\Godot\Godot.exe" set "GODOT_EXE=%LOCALAPPDATA%\Programs\Godot\Godot.exe"
if not defined GODOT_EXE if exist "%ProgramFiles%\Godot\Godot.exe" set "GODOT_EXE=%ProgramFiles%\Godot\Godot.exe"
if not defined GODOT_EXE (
  for /f "delims=" %%G in ('dir /b /s "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*\Godot*.exe" 2^>nul ^| findstr /vi "_console"') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)

if not defined GODOT_EXE (
  echo Godot nebyl nalezen. Nejdrive jednou spust SPUSTIT_HRU.bat.
  pause
  exit /b 1
)

echo Spoustim hru...
start "" "%GODOT_EXE%" --path "%~dp0"
exit /b 0
