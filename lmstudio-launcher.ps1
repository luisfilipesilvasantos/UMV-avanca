$lmPath = "C:\Program Files\LM Studio\LM Studio.exe"
$log = "$env:USERPROFILE\lmstudio-launch.log"

function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $log -Value "$timestamp - $msg"
}

Log "Launcher iniciado."

if (!(Test-Path $lmPath)) {
    Log "LM Studio nao encontrado."
    Write-Host "LM Studio nao encontrado."
    exit
}

Log "A iniciar LM Studio..."
Start-Process $lmPath

Start-Sleep -Seconds 5

$running = Get-Process | Where-Object { $_.ProcessName -like "LM Studio*" }

if ($running) {
    Log "LM Studio iniciado com sucesso."
    Write-Host "LM Studio esta a correr."
} else {
    Log "Falha ao iniciar LM Studio."
    Write-Host "Erro ao iniciar LM Studio."
}

