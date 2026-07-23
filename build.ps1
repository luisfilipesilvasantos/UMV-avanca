# Script de build da DLL UMC
$ErrorActionPreference = "Stop"

# Configurações
echo "Configurando ambiente..."
$SolutionDir = $PSScriptRoot
$Platform = "x64"
$Configuration = "Release"

# Verificar se o MSBuild está instalado
$MsBuildPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\amd64\msbuild.exe"
if (-not (Test-Path $MsBuildPath)) {
    Write-Host "Erro: Não foi possível encontrar o MSBuild." -ForegroundColor Red
    exit 1
}

# Criar pasta de saída
echo "Criando pasta bin/..."
New-Item -ItemType Directory -Path "$SolutionDir\bin" -Force | Out-Null

# Compilar usando MSBuild
echo "Compilando UMC.dll..."
& $MsBuildPath "$SolutionDir\UMC.sln" /p:Platform=$Platform /p:Configuration=$Configuration /v:minimal

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build concluído com sucesso!" -ForegroundColor Green
    Write-Host "DLL gerada em: $SolutionDir\bin\UMC.dll"
} else {
    Write-Host "Erro no build. Verifique os logs." -ForegroundColor Red
    exit 1
}
