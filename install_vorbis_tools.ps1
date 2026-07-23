$toolsDir = "C:\AudioTools\vorbis-tools"
$zipUrl = "https://downloads.xiph.org/releases/vorbis/vorbis-tools-1.4.0.zip"
$zipFile = "$toolsDir\vorbis-tools.zip"

# Criar diretório
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

# Download
Write-Host "Baixando Vorbis Tools..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile

# Extrair
Write-Host "Extraindo..."
Expand-Archive -Path $zipFile -DestinationPath $toolsDir -Force

# Adicionar ao PATH
Write-Host "Adicionando ao PATH..."
$envPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($envPath -notlike "*$toolsDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$envPath;$toolsDir", "User")
}

Write-Host "Vorbis Tools instalado com sucesso."
Write-Host "Comandos disponíveis: oggenc, oggdec, ogginfo, vcut"
Write-Host "Reinicie o PowerShell para ativar os comandos."

