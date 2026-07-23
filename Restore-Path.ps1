# Restore-Path.ps1
# Restaura os caminhos do PATH a partir do backup usando o Add-Path.ps1

$backupFile = "$PSScriptRoot\path_backup.txt"
$addPathScript = "$PSScriptRoot\Add-Path.ps1"

if (-not (Test-Path $backupFile)) {
    Write-Error "❌ Ficheiro de backup não encontrado: $backupFile. Corre primeiro o Backup-Path.ps1."
    return
}

if (-not (Test-Path $addPathScript)) {
    Write-Error "❌ Script Add-Path.ps1 não encontrado em: $addPathScript"
    return
}

# Ler os caminhos do ficheiro
$savedPath = Get-Content -Path $backupFile -Raw
$pathsToRestore = $savedPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }

if ($pathsToRestore.Count -gt 0) {
    Write-Host "�"� A restaurar $($pathsToRestore.Count) caminhos usando Add-Path.ps1..." -ForegroundColor Cyan
    
    # Executar o Add-Path.ps1 com o array de caminhos
    & $addPathScript -NewPaths $pathsToRestore
} else {
    Write-Warning "Nenhum caminho encontrado no ficheiro de backup."
}

