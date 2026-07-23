# ================================
# Script de Build para UMC (sem CUDA)
# Autor: Luis
# ================================

# Caminho do CUDA Toolkit (opcional, usado apenas se necessário)
$cuda = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3"

# Início do timer
$start = Get-Date
Write-Host "Iniciando compilação UMC sem CUDA..."

# Limpar builds anteriores
Write-Host "Limpando ficheiros OBJ..."
Get-ChildItem *.obj -ErrorAction SilentlyContinue | Remove-Item -Force

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

# Compilar apenas os arquivos necessários para o executável sem CUDA
Write-Host "Compilando código fonte (umc_no_cuda.cpp, VirtualGpuMemory.cpp, UMCModelLoader.cpp)..."
cl /c /EHsc /std:c++17 /I "$cuda\include" umc_no_cuda.cpp VirtualGpuMemory.cpp UMCModelLoader.cpp

# Verificar se a compilação foi bem-sucedida
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro na compilação. Código de saída: $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Linkar os objetos gerados (tudo numa linha, sem quebras com crase)
Write-Host "Linkando executável..."
link /OUT:umc_no_cuda.exe umc_no_cuda.obj VirtualGpuMemory.obj UMCModelLoader.obj /LIBPATH:"$cuda\lib\x64" cudart.lib cuda.lib

# Verificar se o link foi bem-sucedido
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro no link. Código de saída: $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Verificar se o executável foi criado
if (Test-Path "umc_no_cuda.exe") {
    $end = Get-Date
    $duration = ($end - $start).TotalSeconds
    Write-Host "Build concluído com sucesso!"
    Write-Host "Tempo total: $duration segundos"
    Write-Host "Executável: umc_no_cuda.exe"
} else {
    Write-Host "Erro: umc_no_cuda.exe não foi gerado."
    exit 1
}
