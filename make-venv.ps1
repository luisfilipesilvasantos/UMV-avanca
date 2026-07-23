param(
    [Parameter(Mandatory=$true)]
    [string]$NomeAmbiente,

    [string]$PythonVersion = "3.10.11"
)

$pythonExe = "C:\py\pyenv\pyenv-win\versions\$PythonVersion\python.exe"

if (-not (Test-Path $pythonExe)) {
    Write-Error "Python $PythonVersion n√£o encontrado em $pythonExe"
    exit 1
}

Write-Host "üêç A criar venv '$NomeAmbiente' com Python $PythonVersion..." -ForegroundColor Cyan
& $pythonExe -m venv $NomeAmbiente

if ($LASTEXITCODE -eq 0) {
    Write-Host "‚ú... Venv '$NomeAmbiente' criado com sucesso." -ForegroundColor Green
    Write-Host "ü'â Para activar: & '.\$NomeAmbiente\Scripts\Activate.ps1'" -ForegroundColor Yellow
} else {
    Write-Error "Erro ao criar o venv."
}
