@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\coleta-diagnostico.ps1 %*
exit /b %ERRORLEVEL%

