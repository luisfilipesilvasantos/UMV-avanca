@echo off
setlocal enabledelayedexpansion

echo === Setup CUDA 12.2 + cuDNN 9 para ComfyUI ===

:: 1. Remover onnxruntime antigo
echo >> A remover onnxruntime antigo...
pip uninstall -y onnxruntime onnxruntime-gpu

:: 2. Instalar onnxruntime-gpu 1.22.0
echo >> A instalar onnxruntime-gpu 1.22.0...
pip install --upgrade pip
pip install onnxruntime-gpu==1.22.0

:: 3. Preparar paths temporários
set CUDA_EXE=%TEMP%\cuda_12.2_installer.exe
set CUDNN_ZIP=C:\Temp\cudnn9.zip

:: 4. Descarregar e instalar CUDA 12.2
if not exist %CUDA_EXE% (
    echo >> A descarregar CUDA 12.2...
    Invoke-WebRequest -Uri https://developer.download.nvidia.com/compute/cuda/12.2.0/local_installers/cuda_12.2.0_windows_network.exe -OutFile %CUDA_EXE%
)
echo >> A instalar CUDA 12.2 (isto pode demorar)...
start /wait  %CUDA_EXE% -s

:: 5. Instalar cuDNN 9 (tens de meter manualmente em C:\Temp\cudnn9.zip)
if exist %CUDNN_ZIP% (
    echo >> A extrair cuDNN...
    7z x %CUDNN_ZIP% -oC:\Temp\cudnn -y

    echo >> A copiar ficheiros cuDNN...
    xcopy /s /y C:\Temp\cudnn\bin\*.dll C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.2\bin\
    xcopy /s /y C:\Temp\cudnn\include\*.h C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.2\include\
    xcopy /s /y C:\Temp\cudnn\lib\x64\*.lib C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.2\lib\x64\
) else (
    echo ⚠️ Não encontrei %CUDNN_ZIP%. Mete manualmente em C:\Temp.
)

:: 6. Configurar variáveis de ambiente
echo >> A configurar variáveis de ambiente...
setx CUDA_PATH C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.2 /M
setx PATH %PATH%;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.2\bin;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.


