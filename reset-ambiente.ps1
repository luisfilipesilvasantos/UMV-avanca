@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\reset-ambiente.ps1 %*
exit /b %ERRORLEVEL%

