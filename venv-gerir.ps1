@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\venv-gerir.ps1 %*
exit /b %ERRORLEVEL%

