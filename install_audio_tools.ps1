# ==========================================================
#  Script: install_audio_tools.ps1
#  Autor: Luis (versão final 2026)
#  Objetivo: Instalar utilitários de áudio no Windows
#  Sem Set-ExecutionPolicy (compatível com políticas bloqueadas)
# ==========================================================

Write-Host "Iniciando instalação de ferramentas de áudio..." -ForegroundColor Cyan

# ----------------------------------------------------------
# Instalar Scoop (sem ExecutionPolicy)
# ----------------------------------------------------------
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop não encontrado. Instalando Scoop..."
    Invoke-Expression (Invoke-WebRequest -UseBasicParsing -Uri "https://get.scoop.sh").Content
} else {
    Write-Host "Scoop já está instalado."
}

# ----------------------------------------------------------
# Instalar Chocolatey (sem ExecutionPolicy)
# ----------------------------------------------------------
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey não encontrado. Instalando Chocolatey..."
    Invoke-WebRequest https://community.chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
} else {
    Write-Host "Chocolatey já está instalado."
}

# ----------------------------------------------------------
# Função Scoop: instalar se faltar
# ----------------------------------------------------------
function ScoopInstallIfMissing($pkg) {
    if (scoop list | Select-String $pkg) {
        Write-Host "$pkg já está instalado (Scoop)."
    } else {
        Write-Host "Instalando $pkg via Scoop..."
        scoop install $pkg
    }
}

# ----------------------------------------------------------
# Função Chocolatey: instalar se faltar
# ----------------------------------------------------------
function ChocoInstallIfMissing($pkg) {
    if (choco list --local-only | Select-String $pkg) {
        Write-Host "$pkg já está instalado (Chocolatey)."
    } else {
        Write-Host "Instalando $pkg via Chocolatey..."
        choco install $pkg -y
    }
}

# ----------------------------------------------------------
# Instalação dos utilitários de áudio
# ----------------------------------------------------------

ScoopInstallIfMissing "sox"
ScoopInstallIfMissing "rubberband"
ScoopInstallIfMissing "ffmpeg"
ChocoInstallIfMissing "lame"
ScoopInstallIfMissing "opus-tools"
ScoopInstallIfMissing "flac"
ScoopInstallIfMissing "vorbis-tools"
ScoopInstallIfMissing "mpg123"
ScoopInstallIfMissing "wavpack"
ScoopInstallIfMissing "libsndfile"
ScoopInstallIfMissing "libsamplerate"

Write-Host "Instalação de ferramentas de áudio concluída." -ForegroundColor Green

