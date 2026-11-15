@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-user-apk.ps1" %*
exit /b %errorlevel%
