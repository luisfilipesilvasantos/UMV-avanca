# =====================================================================
# UMC Unified Memory Launcher para PyTorch e ComfyUI (Windows 11)
# =====================================================================

$ErrorActionPreference = "Stop"

# Passo 1: Verificar se estamos a correr como Administrador
Write-Host "[PASSO 1] A verificar privilégios de administrador..." -ForegroundColor Cyan

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[AVISO] Não estás a correr como Administrador! A alocação de Aperture Pinned Memory (cudaHostAlloc) funciona melhor com privilégios de Admin." -ForegroundColor Yellow
}

# Passo 2: Compilar a biblioteca dinâmica final do UMC (DLL/EXE)
Write-Host "[PASSO 2] Compilando Driver de Memória Unificada C++..." -ForegroundColor Cyan

if (Test-Path ".\build_fixed.ps1") {
    powershell -ExecutionPolicy Bypass -File .\build_fixed.ps1
} else {
    Write-Host "[ERRO] build_fixed.ps1 não encontrado para compilar o driver C++." -ForegroundColor Red
    exit 1
}

# Passo 3: Configurar variáveis de ambiente críticas
Write-Host "[PASSO 3] Aplicando definições de kernel na pilha CUDA do Windows 11..." -ForegroundColor Green

[System.Environment]::SetEnvironmentVariable("PYTORCH_CUDA_ALLOC_CONF", "max_split_size_mb:128,backend:cudaMallocAsync", "Process")
[System.Environment]::SetEnvironmentVariable("CUDA_MODULE_LOADING", "LAZY", "Process")
[System.Environment]::SetEnvironmentVariable("OMP_NUM_THREADS", "8", "Process")

# Passo 4: Localizar a pasta do ComfyUI no sistema
Write-Host "[PASSO 4] A localizar o ComfyUI..." -ForegroundColor Cyan
$comfyPath = "C:\Comfy-Desktop\Comfy Desktop"

if (-not (Test-Path $comfyPath)) {
    Write-Host "[CONFIG] ComfyUI não encontrado no caminho padrão." -ForegroundColor Yellow
    $comfyPath = Read-Host "Insere o caminho completo para a tua pasta do ComfyUI (ou pressiona Enter para simular em modo de teste)"
}

# Passo 5: Lançar o ComfyUI com UMC ativo
if (-not [string]::IsNullOrEmpty($comfyPath) -and (Test-Path $comfyPath)) {
    Write-Host "[PASSO 5] Iniciando ComfyUI com Gestor de Memória Unificada Ativo..." -ForegroundColor Green
    Set-Location $comfyPath
    python main.py --highvram --gpu-only
} else {
    Write-Host "[TESTE] Configurações prontas! Podes agora iniciar a tua aplicação de IA." -ForegroundColor Yellow
}
