@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\extrair-logs.ps1 %*
exit /b %ERRORLEVEL%

