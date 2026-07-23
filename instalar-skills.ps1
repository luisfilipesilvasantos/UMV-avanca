@echo off
title Instalar binários para Clawdbot Skills
echo.
echo [1/6] A verificar se o Chocolatey está instalado...
where choco >nul 2>&1
if %errorlevel% neq 0 (
    echo Chocolatey não encontrado. A instalar...
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString(https://community.chocolatey.org/install.ps1))
) else (
    echo Chocolatey já está instalado.
)

echo.
echo [2/6] A instalar ffmpeg...
choco install -y ffmpeg

echo.
echo [3/6] A instalar jq e ripgrep...
choco install -y jq ripgrep

echo.
echo [4/6] A instalar Python 3...
choco install -y python

echo.
echo [5/6] A instalar Node.js...
choco install -y nodejs

echo.
echo [6/6] A instalar clawdhub CLI...
call npm install -g clawdhub

echo.
echo Instalação concluída. Reinicia o Clawdbot com:
echo     clawdbot gateway restart
pause


