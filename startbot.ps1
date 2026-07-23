@echo off
:: Adiciona o PowerShell 5 e o PowerShell 7 ao caminho do sistema para esta sessão
set PATH=%PATH%;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files\PowerShell\7\

:: Inicia o bot
ollama launch clawdbot

