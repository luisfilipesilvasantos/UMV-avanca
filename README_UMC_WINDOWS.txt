=== UMC PARA WINDOWS 11 + COMFYUI ===

FICHEIROS CRIADOS:
1. UMC.exe - Gestor de Memória Unificada (funcional)
2. start_comfyui_with_umc.bat - Script para iniciar ComfyUI com UMC ativo
3. install_comfyui.bat - Instalação rápida do ComfyUI via pip
4. VirtualGpuMemory_simple.h/cpp - Implementação simplificada (sem CUDA)
5. main_simple.cpp - Teste básico do UMC

COMO USAR:
1. Corre 'install_comfyui.bat' para instalar o ComfyUI
2. Depois corre 'start_comfyui_with_umc.bat'
3. O UMC configurará a memória unificada e iniciará o ComfyUI em modo high-vram

NOTA: Se já tiveres o ComfyUI instalado, podes usar diretamente start_comfyui_with_umc.bat.
O UMC.exe funciona como um pré-carregador que configura as variáveis de ambiente corretas.