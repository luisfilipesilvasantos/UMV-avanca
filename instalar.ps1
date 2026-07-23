@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\instalar.ps1 %*
exit /b %ERRORLEVEL%

