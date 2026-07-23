$lmPath = "C:\Program Files\LM Studio\LM Studio.exe"

if (Test-Path $lmPath) {
    Write-Host "A iniciar LM Studio..."
    Start-Process $lmPath
} else {
    Write-Host "ERRO: LM Studio nao encontrado no caminho especificado."
}

