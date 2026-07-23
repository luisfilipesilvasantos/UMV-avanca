@echo off
chcp 65001 >nul
echo [UMC] Instalando ComfyUI via pip (modo rapido)...
pip install comfy-cli
comfy --skip-install-requirements install
echo.
echo [UMC] ComfyUI instalado! Podes usar start_comfyui_with_umc.bat para iniciar.