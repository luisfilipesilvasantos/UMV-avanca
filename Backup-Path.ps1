# Backup-Path.ps1
# Guarda o PATH atual do utilizador num ficheiro para restauro posterior.

$backupFile = "$PSScriptRoot\path_backup.txt"
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

if ($currentPath) {
    $currentPath | Out-File -FilePath $backupFile -Encoding utf8
    Write-Host "�... Backup do PATH (User) guardado em: $backupFile" -ForegroundColor Green
} else {
    Write-Warning "O PATH do utilizador está vazio ou não pôde ser lido."
}

