@echo off
rem Removes Drop Convert: closes it, deletes its shortcuts and its folder. ffmpeg stays installed.
setlocal
set "DEST=%LOCALAPPDATA%\DropConvert"
taskkill /im DropConvert.exe /f >nul 2>&1
powershell -NoProfile -Command "foreach ($d in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) { Remove-Item -LiteralPath (Join-Path $d 'Drop Convert.lnk') -ErrorAction SilentlyContinue }"
if exist "%DEST%" rmdir /s /q "%DEST%"
echo Drop Convert was removed.
pause
