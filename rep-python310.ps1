# ================================
#  FIX COMFYUI DESKTOP PYTHON
#  Autor: Luis + Copilot
#  Objetivo: Substituir Python 3.13 por Python 3.10 embed
# ================================

Write-Host "=== Reparação ComfyUI Desktop: Substituir Python 3.13 por Python 3.10 ===" -ForegroundColor Cyan

# --- CONFIGURAÇÃO ---
$desktopPath = "C:\Comfy-Desktop\Comfy Desktop\resources\bootstrap-python"
$pythonEmbedPath = "C:\Users\luisf\Downloads\python-3.10.11-embed-amd64"

# --- VERIFICAR EXISTÊNCIA ---
if (!(Test-Path $desktopPath)) {
    Write-Host "ERRO: Pasta bootstrap-python não encontrada!" -ForegroundColor Red
    exit
}

if (!(Test-Path $pythonEmbedPath)) {
    Write-Host "ERRO: Pasta python-3.10.11-embed-amd64 não encontrada!" -ForegroundColor Red
    exit
}

Write-Host "Pasta bootstrap-python encontrada."
Write-Host "Pasta python 3.10 embed encontrada."
Start-Sleep -Seconds 1

# --- LIMPAR PYTHON ANTIGO ---
Write-Host "A remover Python antigo (3.13)..." -ForegroundColor Yellow
Remove-Item "$desktopPath\*" -Recurse -Force
Start-Sleep -Seconds 1

# --- COPIAR PYTHON 3.10 ---
Write-Host "A copiar Python 3.10 embed..." -ForegroundColor Yellow
Copy-Item "$pythonEmbedPath\*" $desktopPath -Recurse -Force
Start-Sleep -Seconds 1

# --- EDITAR python310._pth ---
Write-Host "A configurar python310._pth..." -ForegroundColor Yellow
$pthFile = "$desktopPath\python310._pth"

if (Test-Path $pthFile) {
    Set-Content -Path $pthFile -Value @"
python310.zip
.
import site
"@
} else {
    Write-Host "AVISO: python310._pth não encontrado, criando novo..." -ForegroundColor DarkYellow
    Set-Content -Path $pthFile -Value @"
python310.zip
.
import site
"@
}

Start-Sleep -Seconds 1

# --- INSTALAR PIP ---
Write-Host "A instalar pip..." -ForegroundColor Yellow
Set-Location $desktopPath
Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "get-pip.py"
.\python.exe get-pip.py

# --- VALIDAR PIP ---
Write-Host "A validar pip..." -ForegroundColor Yellow
.\python.exe -m pip --version

# --- INSTALAR PYTORCH CUDA ---
Write-Host "A instalar PyTorch CUDA 12.1..." -ForegroundColor Yellow
.\python.exe -m pip install torch==2.1.0+cu121 torchvision==0.16.0+cu121 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121

# --- VALIDAR TORCH ---
Write-Host "A validar instalação do Torch..." -ForegroundColor Yellow
.\python.exe -c "import torch; print(torch.version.cuda)"

Write-Host "=== Reparação concluída! ===" -ForegroundColor Green
Write-Host "Agora podes abrir o ComfyUI Desktop sem freeze a 65%." -ForegroundColor Green

