# ============================================
#  Windows 11 Post-Install Script (Luis)
#  Versão: 2026-07-01
#  Limpo, sem emojis, sem caracteres invisíveis
#  Com deteção automática de software instalado
# ============================================

Write-Host "Iniciando script pós-instalação..." -ForegroundColor Cyan

# --------------------------------------------
# Função: Verificar se um pacote Winget está instalado
# --------------------------------------------
function IsInstalled($packageId) {
    $pkg = winget list --id $packageId 2>$null
    return ($pkg -match $packageId)
}

# --------------------------------------------
# Função: Instalar pacote Winget se faltar
# --------------------------------------------
function InstallIfMissing($packageId, $name) {
    if (IsInstalled $packageId) {
        Write-Host "$name já está instalado."
    } else {
        Write-Host "Instalando $name..."
        winget install --id $packageId --accept-package-agreements --accept-source-agreements -h
    }
}

# --------------------------------------------
# Atualizar Winget
# --------------------------------------------
Write-Host "Atualizando fontes do Winget..."
winget source update
winget upgrade --all --accept-package-agreements --accept-source-agreements

# --------------------------------------------
# Ativar funcionalidades essenciais do Windows
# --------------------------------------------
Write-Host "Ativando funcionalidades essenciais do Windows..."

$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "NetFx3",
    "NetFx4-AdvSrvs"
)

foreach ($f in $features) {
    Write-Host "Ativando: $f"
    dism /online /enable-feature /featurename:$f /all /norestart
}

# --------------------------------------------
# Instalar aplicações essenciais
# --------------------------------------------
Write-Host "Instalando aplicações essenciais..."

InstallIfMissing "Microsoft.WindowsTerminal" "Windows Terminal"
InstallIfMissing "Git.Git" "Git"
InstallIfMissing "Python.Python.3.11" "Python 3.11"
InstallIfMissing "7zip.7zip" "7-Zip"
InstallIfMissing "Notepad++.Notepad++" "Notepad++"
InstallIfMissing "VideoLAN.VLC" "VLC Player"
InstallIfMissing "Microsoft.PowerShell" "PowerShell 7"
InstallIfMissing "Google.Chrome" "Google Chrome"
InstallIfMissing "Mozilla.Firefox" "Mozilla Firefox"

# --------------------------------------------
# Ferramentas de desenvolvimento
# --------------------------------------------
Write-Host "Instalando ferramentas de desenvolvimento..."

InstallIfMissing "OpenJS.NodeJS" "Node.js + npm"
InstallIfMissing "Rustlang.Rustup" "Rust"
InstallIfMissing "Microsoft.VisualStudio.2022.BuildTools" "Visual Studio Build Tools 2022"
InstallIfMissing "GitHub.GitHubDesktop" "GitHub Desktop"
InstallIfMissing "Postman.Postman" "Postman"
InstallIfMissing "Docker.DockerDesktop" "Docker Desktop"

# --------------------------------------------
# NVIDIA CUDA Toolkit + Nsight
# --------------------------------------------
Write-Host "Instalando NVIDIA CUDA Toolkit e ferramentas..."

InstallIfMissing "Nvidia.CUDA" "NVIDIA CUDA Toolkit"
InstallIfMissing "Nvidia.NsightCompute" "NVIDIA Nsight Compute"
InstallIfMissing "Nvidia.NsightSystems" "NVIDIA Nsight Systems"

# --------------------------------------------
# Drivers (Intel / AMD / NVIDIA)
# --------------------------------------------
Write-Host "Instalando drivers..."

InstallIfMissing "Intel.IntelDriverAndSupportAssistant" "Intel Driver Assistant"
InstallIfMissing "AMD.Software" "AMD Radeon Software"
InstallIfMissing "Nvidia.GeForceExperience" "NVIDIA GeForce Experience"

# --------------------------------------------
# Limpeza e otimização (versão moderna, segura)
# --------------------------------------------
Write-Host "Limpando arquivos temporários..."
Get-ChildItem "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem "$env:TEMP" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "Limpando cache do Windows Update (modo seguro)..."
Try {
    Stop-Service wuauserv -Force -ErrorAction Stop
    Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service wuauserv
} Catch {
    Write-Host "Windows Update está ocupado. A limpeza será ignorada."
}

Write-Host "Limpando logs antigos..."
Remove-Item "C:\Windows\Logs\*" -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "Otimizando SSD..."
Try {
    Optimize-Volume -DriveLetter C -ReTrim -Verbose
} Catch {
    Write-Host "O disco está ocupado. A otimização será ignorada."
}

Write-Host "Script concluído com sucesso." -ForegroundColor Green

