@echo off
setlocal enabledelayedexpansion

:: Caminho da pasta
set TARGET=C:\Users\%USERNAME%\Pictures
set LOG=%TEMP%\desbloqueio_log.txt

:: Limpa log anterior
if exist %LOG% del %LOG%

echo [INFO] Verificando permissões para: %TARGET% >> %LOG%

:: Verifica se está em modo administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Este script precisa ser executado como Administrador.
    echo Execute como administrador e tente novamente.
    pause
    exit /b
)

:: Toma posse da pasta
echo [PASSO] Tomando posse da pasta... >> %LOG%
takeown /f %TARGET% /r /d y >> %LOG% 2>&1

:: Aplica permissões
echo [PASSO] Aplicando permissões para %USERNAME%... >> %LOG%
icacls %TARGET% /grant %COMPUTERNAME%\%USERNAME%:(OI)(CI)F /T >> %LOG% 2>&1

:: Testa gravação
echo [PASSO] Testando gravação... >> %LOG%
echo Teste de gravação > %TARGET%\teste_de_gravacao.txt
if exist %TARGET%\teste_de_gravacao.txt (
    echo [SUCESSO] Gravação bem-sucedida em %TARGET% >> %LOG%
) else (
    echo [FALHA] Não foi possível gravar em %TARGET% >> %LOG%
)

:: Verifica Defender (Acesso controlado a pastas)
echo [INFO] Verificando status do Windows Defender... >> %LOG%
Get-MpPreference | Select-Object -ExpandProperty ControlledFolderAccessProtection >> %LOG% 2>&1

echo.
echo [CONCLUÍDO] Verificação completa. Log salvo em: %LOG%
pause


