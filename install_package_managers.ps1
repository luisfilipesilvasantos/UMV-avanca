# ==========================================================
#  Script: install_package_managers.ps1
#  Autor: Luis (versão final 2026)
#  Objetivo: Instalar package managers do Windows
#  Verifica se já está instalado e ignora duplicados
# ==========================================================

Write-Host "Iniciando instalação de package managers..." -ForegroundColor Cyan

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
# Scoop (instalação manual porque não existe via winget)
# ----------------------------------------------------------
Write-Host "Verificando Scoop..."
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando Scoop..."
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    iwr -useb get.scoop.sh | iex
} else {
    Write-Host "Scoop já está instalado."
}

# ----------------------------------------------------------
# Chocolatey (instalação manual)
# ----------------------------------------------------------
Write-Host "Verificando Chocolatey..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex
} else {
    Write-Host "Chocolatey já está instalado."
}

# ----------------------------------------------------------
# Winget (já vem no Windows 11)
# ----------------------------------------------------------
Write-Host "Verificando Winget..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget não encontrado. Instale Desktop App Installer pela Microsoft Store."
} else {
    Write-Host "Winget já está instalado."
}

# ----------------------------------------------------------
# Yarn
# ----------------------------------------------------------
InstallIfMissing "Yarn.Yarn" "Yarn"

# ----------------------------------------------------------
# PNPM
# ----------------------------------------------------------
InstallIfMissing "pnpm.pnpm" "PNPM"

# ----------------------------------------------------------
# NVM para Windows
# ----------------------------------------------------------
InstallIfMissing "CoreyButler.NVMforWindows" "NVM (Node Version Manager)"

# ----------------------------------------------------------
# Oh My Posh
# ----------------------------------------------------------
InstallIfMissing "JanDeDobbeleer.OhMyPosh" "Oh My Posh"

# ----------------------------------------------------------
# pipx (Python package manager)
# ----------------------------------------------------------
Write-Host "Verificando pipx..."
if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando pipx..."
    python -m pip install --user pipx
    python -m pipx ensurepath
} else {
    Write-Host "pipx já está instalado."
}

# ----------------------------------------------------------
# Cargo (Rust)
# ----------------------------------------------------------
InstallIfMissing "Rustlang.Rustup" "Rust + Cargo"

# ----------------------------------------------------------
# Composer (PHP)
# ----------------------------------------------------------
InstallIfMissing "Composer.Composer" "Composer (PHP)"

# ----------------------------------------------------------
# NuGet CLI
# ----------------------------------------------------------
InstallIfMissing "NuGet.NuGet" "NuGet CLI"

# ----------------------------------------------------------
# MSYS2 (opcional)
# ----------------------------------------------------------
InstallIfMissing "MSYS2.MSYS2" "MSYS2 (pacman)"

Write-Host "Instalação de package managers concluída." -ForegroundColor Green

