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

Write-Host "`n=== Pastas suspeitas em System32 ===" -ForegroundColor Cyan

Get-ChildItem -Path $src -Directory -ErrorAction SilentlyContinue | Where-Object {
    $keywords -contains $_.Name
} | ForEach-Object {
    Write-Host "  [ENCONTRADO] $($_.FullName)" -ForegroundColor Yellow
}

Write-Host "`nPronto. Revê a lista antes de correr o script de mover." -ForegroundColor Green
