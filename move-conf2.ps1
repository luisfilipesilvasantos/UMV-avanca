$pastas = @(
    "C:\Windows\System32\ComfyUI_windows_portable",
    "C:\Windows\System32\ComfyUI_Tutoriais"
)

$backup = "D:\ComfyUI_windows_portable_nvidia_cu126\backup"
$log    = "C:\robocopy_comfyui_backup.log"

# Criar pasta de destino se nao existir
if (-not (Test-Path $backup)) {
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Write-Host "Pasta de backup criada: $backup" -ForegroundColor Cyan
}

foreach ($src in $pastas) {

    if (-not (Test-Path $src)) {
        Write-Host "[IGNORADO] Nao encontrado: $src" -ForegroundColor DarkYellow
        continue
    }

    $nome = Split-Path $src -Leaf
    $dst  = Join-Path $backup $nome

    Write-Host "`n>>> A copiar: $src" -ForegroundColor Cyan
    Write-Host "         para: $dst" -ForegroundColor Cyan

    robocopy $src $dst /E /COPYALL /R:3 /W:5 /LOG+:$log /TEE

    if ($LASTEXITCODE -lt 8) {
        Write-Host "[OK] Copia concluida. A apagar origem..." -ForegroundColor Green
        Remove-Item -Path $src -Recurse -Force
        Write-Host "[OK] Origem removida: $src" -ForegroundColor Green
    } else {
        Write-Host "[ERRO] Robocopy falhou (codigo $LASTEXITCODE). Origem mantida." -ForegroundColor Red
        Write-Host "       Ver log completo: $log" -ForegroundColor Red
    }
}

Write-Host "`n=== Concluido! Log em: $log ===" -ForegroundColor Green
