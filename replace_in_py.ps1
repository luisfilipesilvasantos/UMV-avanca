# ================================================
# replace_in_py.ps1 - Substituidor de blocos em .py
# Uso: .\replace_in_py.ps1 -file "app.py" -search "texto antigo" -replace "texto novo"
# ================================================

param(
    [string]$file = "",                    # Caminho do ficheiro .py
    [string]$search = "",                  # Texto ou bloco a procurar
    [string]$replace = "",                 # Texto ou bloco de substituição
    [switch]$All = $false,                 # Substituir todas as ocorrências
    [switch]$Backup = $true                # Criar backup antes de alterar
)

if ($file -eq "" -or $search -eq "") {
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host ".\replace_in_py.ps1 -file 'caminho\app.py' -search 'bloco antigo' -replace 'bloco novo' [-All] [-Backup:`$false]" -ForegroundColor Cyan
    Write-Host "`nExemplo com bloco multilinha:" -ForegroundColor Green
    Write-Host '.\replace_in_py.ps1 -file "app.py" -search "def allocateSystemVirtual():" -replace "def allocateSystemVirtual(size_bytes: int, device_id: int = 0) -> torch.Tensor:"' -ForegroundColor White
    exit 1
}

if (-not (Test-Path $file)) {
    Write-Host "Erro: Ficheiro não encontrado: $file" -ForegroundColor Red
    exit 1
}

# Criar backup
if ($Backup) {
    $backupFile = "$file.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $file -Destination $backupFile
    Write-Host "Backup criado: $backupFile" -ForegroundColor Green
}

# Ler o conteúdo
$content = Get-Content -Path $file -Raw -Encoding UTF8

# Fazer a substituição
if ($All) {
    $newContent = $content -replace [regex]::Escape($search), $replace
} else {
    $newContent = $content -replace [regex]::Escape($search), $replace, 1
}

# Verificar se houve mudança
if ($newContent -eq $content) {
    Write-Host "Nenhuma alteração realizada. Texto não encontrado." -ForegroundColor Yellow
} else {
    # Escrever de volta
    $newContent | Set-Content -Path $file -Encoding UTF8
    Write-Host "Substituição realizada com sucesso em $file" -ForegroundColor Green
    Write-Host "Ocorrências substituídas: 1" -ForegroundColor Green
}

Write-Host "Pronto!" -ForegroundColor Cyan
