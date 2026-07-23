# Build ultra-rápido para testes
$cuda = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
if (-not (Test-Path $cuda)) { $cuda = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3" }
Write-Host "Compilando main.cpp e VirtualGpuMemory.cpp..."
cl /c /EHsc /std:c++17 /I "$cuda\include" main.cpp VirtualGpuMemory.cpp 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "Erro na compilação. Tenta sem CUDA..."; cl /c /EHsc /std:c++17 main.cpp VirtualGpuMemory.cpp }
link main.obj VirtualGpuMemory.obj /OUT:UMC.exe 2>&1
if (Test-Path UMC.exe) { Write-Host "Build concluído!" } else { Write-Host "Erro no link." }