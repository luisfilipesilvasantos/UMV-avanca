Write-Host "=== LIMPEZA COMPLETA DO EDGE E WEBVIEW2 ===" -ForegroundColor Cyan

# 1. Fechar processos
Write-Host "[1/7] A terminar processos..." -ForegroundColor Yellow
Get-Process "msedge","msedgewebview2","edgeupdate","edge" -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Desinstalar WebView2 Runtime
Write-Host "[2/7] A desinstalar WebView2 Runtime..." -ForegroundColor Yellow
$webview = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*WebView2*" }
if ($webview) { $webview.Uninstall() }

# 3. Desinstalar Edge
Write-Host "[3/7] A desinstalar o Microsoft Edge..." -ForegroundColor Yellow
$edgeSetup = "C:\Program Files (x86)\Microsoft\Edge\Application\setup.exe"
if (Test-Path $edgeSetup) {
    & $edgeSetup --uninstall --force-uninstall --system-level
}

# 4. Remover diretórios residuais
Write-Host "[4/7] A limpar diretórios residuais..." -ForegroundColor Yellow
$paths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge",
    "$env:LOCALAPPDATA\Microsoft\EdgeUpdate",
    "$env:LOCALAPPDATA\Microsoft\EdgeCore",
    "$env:LOCALAPPDATA\Microsoft\EdgeWebView",
    "$env:PROGRAMDATA\Microsoft\Edge",
    "$env:PROGRAMFILES\Microsoft\Edge",
    "${env:PROGRAMFILES(X86)}\Microsoft\Edge"
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue
    }
}

# 5. Limpar cache de DLLs
Write-Host "[5/7] A limpar cache de DLLs..." -ForegroundColor Yellow
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Temp\Edge*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Temp\WebView*" -ErrorAction SilentlyContinue

# 6. Descarregar instalador oficial do Edge
Write-Host "[6/7] A descarregar instalador oficial..." -ForegroundColor Yellow
$installer = "$env:TEMP\MicrosoftEdgeSetup.exe"
$edgeUrl = "https://go.microsoft.com/fwlink/?linkid=2109047&Channel=Stable&language=en&consent=1"

try {
    Invoke-WebRequest -Uri $edgeUrl -OutFile $installer -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Host "ERRO: falha ao descarregar o instalador do Edge." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Descarrega manualmente em: https://www.microsoft.com/edge" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $installer) -or (Get-Item $installer).Length -eq 0) {
    Write-Host "ERRO: o instalador não foi descarregado corretamente." -ForegroundColor Red
    exit 1
}

# 7. Instalar Edge
Write-Host "[7/7] A reinstalar o Edge..." -ForegroundColor Yellow
try {
    Start-Process $installer -ArgumentList "/install" -Wait -ErrorAction Stop
    Write-Host "=== EDGE REINSTALADO COM SUCESSO ===" -ForegroundColor Green
    Write-Host "Reinicia o PC agora." -ForegroundColor Green
}
catch {
    Write-Host "ERRO: falha ao executar o instalador." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
