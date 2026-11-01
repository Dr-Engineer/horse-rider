@echo off
rem Double-click to play Windhorse Rumble on Windows. Set GODOT to godot.exe, or install it in the default place below.
cd /d "%~dp0"
if not defined GODOT set "GODOT=%LOCALAPPDATA%\Programs\Godot\godot.exe"
if not exist "%GODOT%" (
  echo Godot 4.7 was not found at %GODOT%. Install it from godotengine.org, then set GODOT to its path.
  pause
  exit /b 1
)
start "" "%GODOT%" --path .
