@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\logapp.ps1 %*
exit /b %ERRORLEVEL%

