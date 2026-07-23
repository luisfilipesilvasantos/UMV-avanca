@echo off
chcp 65001 >nul
echo [UMC] Inicializando Gestor de Memoria Unificada...
call .\UMC.exe
echo.
echo [UMC] Configurando variaveis de ambiente para ComfyUI...
set PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128,backend:cudaMallocAsync
set CUDA_MODULE_LOADING=LAZY
set OMP_NUM_THREADS=8
echo.
echo [UMC] A iniciar ComfyUI em modo high-vram...
cd /d "C:\Comfy-Desktop\Comfy Desktop"
python main.py --highvram --gpu-only