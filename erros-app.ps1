@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\erros-app.ps1 %*
exit /b %ERRORLEVEL%

