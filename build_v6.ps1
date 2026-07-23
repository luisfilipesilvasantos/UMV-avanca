# ================================
# Script de Build para UMC (Versão Final Corrigida - sem cuda_runtime_mock.h)
# Autor: Luis
# ================================

# Caminho do CUDA Toolkit
$cuda = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3"

# Início do timer
$start = Get-Date
Write-Host "Iniciando compilação UMC (versão sem cuda_runtime_mock.h)..."

# Limpar builds anteriores
Write-Host "Limpando ficheiros OBJ e EXE..."
Get-ChildItem *.obj, *.exe -ErrorAction SilentlyContinue | Remove-Item -Force

# Inicializar ambiente do Visual Studio (x64)
Write-Host "Inicializando ambiente do Visual Studio..."
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
if (-not (Test-Path $vsPath)) {
    Write-Host "Erro: vcvarsall.bat não encontrado em $vsPath"
    exit 1
}

# Executar vcvarsall.bat e carregar variáveis de ambiente resultantes
$envCmd = "`"$vsPath`" x64 & set"
& cmd /c $envCmd | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Copiar header corrigido para o local correto (substitui VirtualGpuMemory.h)
Write-Host "Copiando VirtualGpuMemory_final_v4.h para VirtualGpuMemory.h..."
Copy-Item -Path "VirtualGpuMemory_final_v4.h" -Destination "VirtualGpuMemory.h" -Force

# Compilar apenas os arquivos necessários para o executável principal
Write-Host "Compilando código fonte (main.cpp, VirtualGpuMemory.cpp, UMCModelLoader.cpp)..."
cl /c /EHsc /std:c++17 /I "$cuda\include" main.cpp VirtualGpuMemory.cpp UMCModelLoader.cpp

# Verificar se a compilação foi bem-sucedida
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro na compilação. Código de saída: $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Linkar os objetos gerados
Write-Host "Linkando executável..."
link /OUT:UMC.exe main.obj VirtualGpuMemory.obj UMCModelLoader.obj `
    /LIBPATH:"$cuda\lib\x64" cudart.lib cuda.lib

# Verificar se o link foi bem-sucedido
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro no link. Código de saída: $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Verificar se o executável foi criado
if (Test-Path "UMC.exe") {
    $end = Get-Date
    $duration = ($end - $start).TotalSeconds

    Write-Host "Build concluído com sucesso!"
    Write-Host "Tempo total: $duration segundos"
    Write-Host "Executável: UMC.exe"
} else {
    Write-Host "Erro: UMC.exe não foi gerado."
    exit 1
}
