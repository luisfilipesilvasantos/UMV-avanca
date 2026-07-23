@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\pip-reparar.ps1 %*
exit /b %ERRORLEVEL%

