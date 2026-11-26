@echo off
rem Installs Drop Convert: builds it into %LOCALAPPDATA%\DropConvert and adds Desktop and Start menu shortcuts.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
