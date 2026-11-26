@echo off
rem Builds DropConvert.exe with the C# compiler that ships with Windows (no downloads).
set NET=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319
set WMD=%WINDIR%\System32\WinMetadata
cd /d "%~dp0"
"%NET%\csc.exe" /nologo /target:winexe /out:DropConvert.exe /win32icon:app.ico ^
  /r:"%NET%\WPF\PresentationFramework.dll" /r:"%NET%\WPF\PresentationCore.dll" ^
  /r:"%NET%\WPF\WindowsBase.dll" /r:"%NET%\System.Xaml.dll" /r:Microsoft.CSharp.dll ^
  /r:"%NET%\System.Runtime.dll" /r:"%WMD%\Windows.Foundation.winmd" /r:"%WMD%\Windows.Storage.winmd" ^
  /r:"%WMD%\Windows.Data.winmd" /r:"%WMD%\Windows.Graphics.winmd" DropConvert.cs
