@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\python-embutido.ps1 %*
exit /b %ERRORLEVEL%

