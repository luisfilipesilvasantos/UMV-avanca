# UMC_Setup_Script.ps1
# Script para instalar automaticamente VS2022, CUDA 12.6+, CMake

Write-Host "=== Setup do Ambiente UMC ===" -ForegroundColor Green

# 1. Verificar e instalar Chocolatey (gerenciador de pacotes para Windows)
$chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoInstalled) {
    Write-Host "Chocolatey não encontrado. Instalando..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    # Reiniciar o shell para carregar o choco
    Write-Host "Chocolatey instalado. Reinicie o PowerShell e execute este script novamente." -ForegroundColor Red
    exit
} else {
    Write-Host "Chocolatey já está instalado." -ForegroundColor Green
}

# 2. Instalar Visual Studio Community 2022 com Workloads Necessários
Write-Host "Instalando Visual Studio Community 2022..." -ForegroundColor Yellow
# Workload para desenvolvimento C++ e SDK do Windows
choco install visualstudio2022community -y --package-parameters "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --locale en-US"

# Opcional: Instalar também o Build Tools (útil para compilar sem abrir o IDE)
# choco install visualstudio2022buildtools -y --package-parameters "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22000 --includeRecommended --locale en-US"

# 3. Instalar CUDA Toolkit 12.6+
Write-Host "Instalando CUDA Toolkit 12.6+..." -ForegroundColor Yellow
# O pacote 'cuda' do Chocolatey instala automaticamente a última versão LTS ou mais recente >= 12.x
choco install cuda -y

# 4. Instalar CMake
Write-Host "Instalando CMake..." -ForegroundColor Yellow
choco install cmake -y

# 5. (Opcional) Adicionar ao PATH manualmente (geralmente o Chocolatey faz automaticamente)
# $env:Path += ";C:\Program Files\CMake\bin;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6\bin"

Write-Host "=== Instalação concluída! ===" -ForegroundColor Green
Write-Host "Por favor, reinicie o PowerShell ou o CMD para recarregar o PATH."
Write-Host "Depois, poderá compilar os primeiros spikes de CUDA."

# 6. (Opcional) Validar instalação
Write-Host "Validando instalação..." -ForegroundColor Cyan
try {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName
    }
    nvcc --version
    cmake --version
    Write-Host "Validação concluída com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "Erro na validação: $_" -ForegroundColor Red
}
