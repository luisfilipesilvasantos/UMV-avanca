# ==========================================================
#  Script: install_from_path.ps1
#  Objetivo: Instalar tudo o que aparece no PATH do Luis
#  Verifica se já está instalado e ignora duplicados
# ==========================================================

Write-Host "Iniciando instalação baseada no PATH..." -ForegroundColor Cyan

# ----------------------------------------------------------
# Função: verificar se um pacote Winget está instalado
# ----------------------------------------------------------
function IsInstalled($packageId) {
    $pkg = winget list --id $packageId 2>$null
    return ($pkg -match $packageId)
}

# ----------------------------------------------------------
# Função: instalar apenas se faltar
# ----------------------------------------------------------
function InstallIfMissing($packageId, $name) {
    if (IsInstalled $packageId) {
        Write-Host "$name já está instalado."
    } else {
        Write-Host "Instalando $name..."
        winget install --id $packageId --accept-package-agreements --accept-source-agreements -h
    }
}

# ----------------------------------------------------------
# Lista de pacotes detectados no PATH
# ----------------------------------------------------------
$packages = @(
    @{ id="Python.Python.3.11"; name="Python 3.11" },
    @{ id="OpenJS.NodeJS"; name="Node.js + npm" },
    @{ id="Git.Git"; name="Git" },
    @{ id="Microsoft.PowerShell"; name="PowerShell 7" },
    @{ id="Microsoft.DotNet.SDK.8"; name=".NET SDK 8" },
    @{ id="JanDeDobbeleer.OhMyPosh"; name="Oh My Posh" },
    @{ id="GnuWin32.Sox"; name="Sox" },
    @{ id="Nvidia.CUDA"; name="NVIDIA CUDA Toolkit" },
    @{ id="Nvidia.NsightCompute"; name="NVIDIA Nsight Compute" },
    @{ id="Nvidia.NsightSystems"; name="NVIDIA Nsight Systems" }
)

# ----------------------------------------------------------
# Instalar pacotes
# ----------------------------------------------------------
foreach ($pkg in $packages) {
    InstallIfMissing $pkg.id $pkg.name
}

Write-Host "Instalação concluída." -ForegroundColor Green

