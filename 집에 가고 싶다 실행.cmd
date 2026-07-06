@echo off
set "GODOT=C:\Users\jeoun\Downloads\Godot_v4.6.2-stable_win64.exe"
set "PROJECT_DIR=%~dp0"
start "" "%GODOT%" --path "%PROJECT_DIR%"
