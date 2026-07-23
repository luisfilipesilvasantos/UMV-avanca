@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\pip-diagnostico.ps1 %*
exit /b %ERRORLEVEL%

