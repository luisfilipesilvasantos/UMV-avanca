@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\projeto-python-criar.ps1 %*
exit /b %ERRORLEVEL%

