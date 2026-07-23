# Configuração para garantir que o output mostra caracteres corretamente
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Iniciando a Automatização Claude Desktop + MCP + LLM Local (Windows 11) ===" -ForegroundColor Cyan

# 1. Instalar as Aplicações via Winget
Write-Host "`n[1/3] Instalando Claude Desktop, Ollama e LM Studio..." -ForegroundColor Yellow
winget install --id Anthropic.Claude --silent --accept-source-agreements --accept-package-agreements
winget install --id Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements
winget install --id LMStudio.LMStudio --silent --accept-source-agreements --accept-package-agreements

# 2. Instalar Node.js (necessário para rodar os servidores MCP via npx)
Write-Host "`n[2/3] Instalando Node.js e NPM para o ecossistema MCP..." -ForegroundColor Yellow
winget install --id OpenJS.NodeJS --silent --accept-source-agreements --accept-package-agreements

# 3. Configurar a pasta e o ficheiro JSON do Claude Desktop
Write-Host "`n[3/3] Configurando o ambiente MCP do Claude Desktop..." -ForegroundColor Yellow

# Caminho padrão do Claude no Windows %APPDATA%\Claude
$ClaudePath = Join-Path $env:APPDATA "Claude"
if (-not (Test-Path $ClaudePath)) {
    New-Item -ItemType Directory -Path $ClaudePath | Out-Null
}

$ConfigFile = Join-Path $ClaudePath "claude_desktop_config.json"

# Obter caminhos de pastas do utilizador para o MCP de ficheiros de forma segura
$UserProfile = $env:USERPROFILE
$DownloadsFolder = "$UserProfile\Downloads" -replace '\\', '\\'
$DocumentsFolder = "$UserProfile\Documents" -replace '\\', '\\'

# Estrutura JSON do MCP (configurado com leitura de ficheiros e fetch de URLs)
$JsonContent = @"
{
  "mcpServers": {
    "filesystem": {
      "command": "npx.cmd",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$DownloadsFolder",
        "$DocumentsFolder"
      ]
    },
    "fetch": {
      "command": "npx.cmd",
      "args": [
        "-y",
        "@modelcontextprotocol/server-fetch"
      ]
    }
  }
}
"@

# Guardar o ficheiro em formato UTF-8 sem BOM (padrão do JSON)
Set-Content -Path $ConfigFile -Value $JsonContent -Encoding UTF8

Write-Host "`n=== Instalação e Configuração Concluídas! ===" -ForegroundColor Green
Write-Host "Configuração do MCP criada em: $ConfigFile" -ForegroundColor Cyan
Write-Host "Dica: Fecha e volta a abrir o Terminal para o comando 'npx' ficar ativo globalmente." -ForegroundColor Magenta
