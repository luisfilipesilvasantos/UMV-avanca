<#
.SYNOPSIS
Cria (ou reutiliza) um ambiente virtual com uma versao especifica do Python via pyenv-win.

.DESCRIPTION
Uso:
  pyenv-use.ps1 -Version 3.10.11 -Name venv310
  pyenv-use.ps1 -Version 3.10.11 -Name venv310 -Path C:\Users\luisf\projetos\app

Cria a pasta <Name> em <Path> (ou cwd se omitido), define o Python global
para <Version> e cria o venv com o modulo nativo venv.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$Name,

    [string]$Path = (Get-Location).Path
)

$venvPath = Join-Path $Path $Name

# 1) Trocar a versao global do pyenv
Write-Host "A trocar Python global para $Version..." -ForegroundColor Cyan
pyenv global $Version
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao trocar para $Version. Versoes disponiveis:"
    pyenv versions
    exit 1
}
python --version

# 2) Criar o venv se nao existir
if (Test-Path $venvPath) {
    Write-Host "Venv ja existe: $venvPath" -ForegroundColor Yellow
} else {
    Write-Host "A criar venv em: $venvPath" -ForegroundColor Cyan
    python -m venv $venvPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha ao criar venv."
        exit 1
    }
    Write-Host "Venv criado." -ForegroundColor Green
}

# 3) Mostrar resumo
Write-Host "`nResumo:" -ForegroundColor Green
Write-Host "  Python:   $(python --version 2>&1)"
Write-Host "  Venv:     $venvPath"
Write-Host "  Ativar:   $venvPath\Scripts\Activate.ps1"
Write-Host "  Sair:     deactivate"

