# Installs Drop Convert for this Windows user. Run by "Install Drop Convert.cmd". No admin rights needed.
# It builds DropConvert.exe from DropConvert.cs with the C# compiler that ships with Windows, so no .exe is downloaded.
$src = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'DropConvert'

if (-not (Test-Path (Join-Path $src 'DropConvert.cs'))) { Write-Host 'Unzip the whole folder first, then run the installer from inside it.'; exit 1 }

Get-Process DropConvert -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Installing to $dest ..."
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Join-Path $src 'DropConvert.cs'), (Join-Path $src 'app.ico'), (Join-Path $src 'build.cmd'), (Join-Path $src 'README.md') $dest -Force

Write-Host 'Building DropConvert.exe ...'
& cmd /c "`"$dest\build.cmd`""
if (-not (Test-Path (Join-Path $dest 'DropConvert.exe'))) { Write-Host 'The build failed (see the messages above).'; exit 1 }

$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
  $l = $shell.CreateShortcut((Join-Path $dir 'Drop Convert.lnk'))
  $l.TargetPath = Join-Path $dest 'DropConvert.exe'
  $l.WorkingDirectory = $dest
  $l.IconLocation = "$dest\app.ico,0"
  $l.Description = 'Drop files on the bubble to convert them'
  $l.Save()
}

Write-Host ''
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) { Write-Host 'ffmpeg found: video, audio and image conversions will work.' }
else {
  Write-Host 'ffmpeg is not installed. Drop Convert needs it for video, audio and images.'
  Write-Host 'It is free. The installer can get it with winget (package Gyan.FFmpeg, the build linked from ffmpeg.org).'
  if ((Read-Host 'Install ffmpeg now? (y/n)') -match '^y') {
    winget install --id Gyan.FFmpeg --exact --accept-source-agreements --accept-package-agreements
    Write-Host 'If conversions still say ffmpeg is missing, sign out of Windows and back in once.'
  }
}
if (-not (Test-Path 'Registry::HKEY_CLASSES_ROOT\Word.Application')) { Write-Host 'Microsoft Word was not found: document and PDF-to-Word conversions need it. The rest still works.' }

Write-Host ''
Write-Host 'Done. Open "Drop Convert" from your Desktop or Start menu, then drop a file on the orange bubble.'
Write-Host 'To remove it later, run "Uninstall Drop Convert.cmd".'
