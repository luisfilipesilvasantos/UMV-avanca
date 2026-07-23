@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\diagnostico-python.ps1 %*
exit /b %ERRORLEVEL%

