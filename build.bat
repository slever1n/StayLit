@echo off
if not exist "%~dp0app.ico" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-icon.ps1"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ /win32icon:"%~dp0app.ico" /out:"%~dp0StayLit.exe" "%~dp0StayLit.cs"
