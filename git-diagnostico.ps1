@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\git-diagnostico.ps1 %*
exit /b %ERRORLEVEL%

