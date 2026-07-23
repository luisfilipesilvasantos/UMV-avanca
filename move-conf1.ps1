$src = "C:\Windows\System32"
$dst = "D:\ComfyUI_windows_portable_nvidia_cu126"

$keywords = @(
    "ComfyUI",
    "custom_nodes",
    "models",
    "output",
    "venv",
    "python_embeded",
    "ComfyUI-Manager"
)

$found = Get-ChildItem -Path $src -Directory -ErrorAction SilentlyContinue | Where-Object {
    $keywords -contains $_.Name
}

if (-not $found) {
    Write-Host "Nenhuma pasta encontrada com os criterios." -ForegroundColor Green
    exit
}

foreach ($folder in $found) {
    $target = Join-Path $dst $folder.Name
    Write-Host "A mover: $($folder.FullName) -> $target" -ForegroundColor Cyan
    try {
        Move-Item -Path $folder.FullName -Destination $target -Force -ErrorAction Stop
        Write-Host "  [OK] Movido." -ForegroundColor Green
    } catch {
        Write-Host "  [ERRO] $_" -ForegroundColor Red
    }
}

Write-Host "`nConcluido!" -ForegroundColor Green
