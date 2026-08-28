@echo off
cd /d "%~dp0"

echo Aktualizuji Lumberjack John...
where git >nul 2>nul
if %errorlevel%==0 (
  git pull --ff-only
)

set GODOT_EXE=
for %%G in (godot.exe godot4.exe) do (
  where %%G >nul 2>nul && set GODOT_EXE=%%G
)

if defined GODOT_EXE (
  start "" %GODOT_EXE% --path "%~dp0" --editor
  exit /b
)

for %%P in (
  "%LOCALAPPDATA%\Programs\Godot\Godot.exe"
  "%ProgramFiles%\Godot\Godot.exe"
  "%ProgramFiles%\Godot\Godot_v4.5-stable_win64.exe"
  "%ProgramFiles%\Godot\Godot_v4.4-stable_win64.exe"
  "%ProgramFiles%\Godot\Godot_v4.3-stable_win64.exe"
) do (
  if exist %%P (
    start "" %%P --path "%~dp0" --editor
    exit /b
  )
)

echo.
echo Godot nebyl nalezen. Nainstaluj Godot 4.x a pak tento soubor spust znovu.
pause
