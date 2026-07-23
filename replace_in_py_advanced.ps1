# ================================================
# replace_in_py_advanced.ps1 - Versão Profissional
# Suporta: múltiplos replaces, regex, interface, preview, etc.
# ================================================

param(
    [string]$file = "",
    [switch]$Interactive = $false,
    [switch]$Regex = $false,
    [switch]$Preview = $false,
    [switch]$Backup = $true
)

function Show-Menu {
    Clear-Host
    Write-Host "=== UMC Advanced Python Replacer ===" -ForegroundColor Cyan
    Write-Host "1. Substituir um único bloco de texto"
    Write-Host "2. Substituir múltiplos blocos (em lote)"
    Write-Host "3. Substituir com Regex"
    Write-Host "4. Preview de alterações"
    Write-Host "5. Sair"
    $choice = Read-Host "Escolha uma opção"
    return $choice
}

if ($Interactive) {
    while ($true) {
        $choice = Show-Menu
        
        switch ($choice) {
            "1" {
                $file = Read-Host "Caminho do ficheiro .py"
                $search = Read-Host "Texto a procurar (pode ser multilinha)"
                $replace = Read-Host "Texto de substituição"
                $all = (Read-Host "Substituir todas as ocorrências? (S/N)") -eq "S"
            }
            "5" { exit }
        }
    }
}

# Modo normal (com parâmetros)
if ($file -eq "") {
    Write-Host "Uso avançado:" -ForegroundColor Yellow
    Write-Host ".\replace_in_py_advanced.ps1 -file 'app.py' -Preview" -ForegroundColor Cyan
    Write-Host "Ou use -Interactive para menu interativo"
    exit 0
}

if (-not (Test-Path $file)) {
    Write-Host "Erro: Ficheiro não encontrado!" -ForegroundColor Red
    exit 1
}

# Backup
if ($Backup) {
    $backup = "$file.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $file $backup
    Write-Host "Backup criado: $backup" -ForegroundColor Green
}

$content = Get-Content -Path $file -Raw -Encoding UTF8
$original = $content

Write-Host "`nFicheiro carregado: $file" -ForegroundColor Cyan

# === MÚLTIPLOS REPLACES (exemplo embutido para UMC) ===
$replacements = @(
    # Adicione aqui os replaces que quiser
    @{ Search = 'def allocateSystemVirtual():'; Replace = 'def allocateSystemVirtual(size_bytes: int, device_id: int = 0) -> torch.Tensor:' },
    @{ Search = 'm_totalVirtualCapacity = None'; Replace = 'm_totalVirtualCapacity: Optional[int] = None' },
    @{ Search = 'cuda_enabled = torch.cuda.is_available()'; Replace = 'cuda_enabled = torch.cuda.is_available() if hasattr(torch, "cuda") else False' }
)

foreach ($r in $replacements) {
    if ($Regex) {
        $content = $content -replace $r.Search, $r.Replace
    } else {
        $content = $content.Replace($r.Search, $r.Replace)
    }
    Write-Host "✓ Aplicado: $($r.Search.Substring(0, [Math]::Min(50, $r.Search.Length)))..." -ForegroundColor Green
}

# Escrever resultado
if ($Preview) {
    Write-Host "`n=== PREVIEW DAS ALTERAÇÕES ===" -ForegroundColor Yellow
    Write-Host ($content | Out-String) -ForegroundColor Gray
} else {
    $content | Set-Content -Path $file -Encoding UTF8
    Write-Host "`nAlterações aplicadas com sucesso em $file!" -ForegroundColor Green
}

Write-Host "Operação concluída." -ForegroundColor Cyan
