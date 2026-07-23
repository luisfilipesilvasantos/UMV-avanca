# ================================
#  Windows 11 Post-Install Script
#  Autor: Luis + Copilot
# ================================

Write-Host " A preparar sistema..." -ForegroundColor Cyan

# 1. Atualizar Winget + fontes
Write-Host " Atualizar Winget..." -ForegroundColor Yellow
winget source update
winget upgrade --all --accept-source-agreements --accept-package-agreements

# 2. Ativar funcionalidades teis do Windows
Write-Host " Ativar funcionalidades opcionais..." -ForegroundColor Yellow
$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "TelnetClient",
    "NetFx3",
    "NetFx4-AdvSrvs",
    "WindowsMediaPlayer"
)

foreach ($f in $features) {
    Write-Host " Ativar: $f"
    dism /online /enable-feature /featurename:$f /all /norestart
}

# 3. Instalar apps essenciais via Winget
Write-Host " Instalar aplicaes essenciais..." -ForegroundColor Yellow

$apps = @(
    "Microsoft.Edge",
    "Microsoft.PowerShell",
    "Microsoft.VisualStudioCode",
    "Git.Git",
    "Python.Python.3",
    "7zip.7zip",
    "Google.Chrome",
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "Notepad++.Notepad++",
    "OBSProject.OBSStudio",
    "Discord.Discord",
    "Valve.Steam",
    "Microsoft.WindowsTerminal",
    "Microsoft.DotNet.SDK.8",
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.VisualStudio.2022.Community",
    "OpenJS.NodeJS",
    "Brave.Brave",
    "Spotify.Spotify"
)

foreach ($app in $apps) {
    Write-Host " Instalar: $app"
    winget install --id $app --accept-source-agreements --accept-package-agreements -h
}

# 4. Instalar drivers (Intel, AMD, Nvidia)
Write-Host " Instalar drivers..." -ForegroundColor Yellow

winget install Intel.IntelDriverAndSupportAssistant -h
winget install Nvidia.GeForceExperience -h
winget install AMD.Software -h

# 5. Instalar ferramentas de desenvolvimento
Write-Host " Instalar ferramentas de desenvolvimento..." -ForegroundColor Yellow

$devtools = @(
    "Docker.DockerDesktop",
    "GitHub.GitHubDesktop",
    "Postman.Postman",
    "Microsoft.AzureCLI",
    "Microsoft.AzureStorageExplorer",
    "JetBrains.Toolbox"
)

foreach ($tool in $devtools) {
    Write-Host " Instalar: $tool"
    winget install --id $tool --accept-source-agreements --accept-package-agreements -h
}

# 6. Limpeza e otimizao
Write-Host " Limpeza e otimizao..." -ForegroundColor Yellow

# Limpar lixo
cmd /c cleanmgr /sagerun:1

# Otimizar disco
Optimize-Volume -DriveLetter C -ReTrim -Verbose

# 7. Atualizar Windows
Write-Host " Atualizar Windows..." -ForegroundColor Yellow
Install-WindowsUpdate -AcceptAll -AutoReboot

Write-Host " Script concludo! Sistema pronto." -ForegroundColor Green


