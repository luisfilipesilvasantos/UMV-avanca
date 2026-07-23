<#
.SYNOPSIS
Imports one or more updates into WSUS using UpdateIDs from the Microsoft Update Catalog.
#>

param(
    [string]$WsusServer = "localhost",

    [ValidateSet(80, 443, 8530, 8531)]
    [int]$PortNumber = 8530,

    [switch]$UseSsl,

    # Opcional
    [string]$UpdateId,

    # Opcional
    [string]$UpdateIdFilePath
)

Set-StrictMode -Version Latest

# Lista final de updates
$updateList = @()

# Se o utilizador passou UpdateId ‚Ü' adiciona
if ($UpdateId) {
    $updateList += $UpdateId.Trim()
}

# Se passou ficheiro ‚Ü' adiciona todos
if ($UpdateIdFilePath) {
    if (-not (Test-Path $UpdateIdFilePath)) {
        Write-Error "Ficheiro n√£o encontrado: $UpdateIdFilePath"
        return
    }

    $fileIds = Get-Content $UpdateIdFilePath | ForEach-Object { $_.Trim() }
    $updateList += $fileIds
}

# Se n√£o passou nada ‚Ü' pedir input interativo
if ($updateList.Count -eq 0) {
    Write-Host "Nenhum UpdateId fornecido. Introduz um ou mais UpdateIDs separados por v√≠rgulas:"
    $manual = Read-Host "UpdateIDs"
    $updateList = $manual.Split(",") | ForEach-Object { $_.Trim() }
}

# Remover vazios
$updateList = $updateList | Where-Object { $_ -ne "" }

if ($updateList.Count -eq 0) {
    Write-Error "Nenhum UpdateID v√°lido encontrado."
    return
}

# Construir par√¢metros WSUS
$wsusParams = @{
    Name       = $WsusServer
    PortNumber = $PortNumber
}

if ($UseSsl) { $wsusParams.UseSsl = $true }

# Conectar ao WSUS
try {
    Write-Host "A ligar ao WSUS (${WsusServer}:${PortNumber})... " -NoNewline
    $server = Get-WsusServer @wsusParams
    Write-Host "OK"
}
catch {
    Write-Error "Falha ao ligar ao WSUS: $_"
    return
}

# Importar updates
$FileList = @()

foreach ($uid in $updateList) {
    try {
        Write-Host "A importar UpdateID: $uid... " -NoNewline
        $server.ImportUpdateFromCatalogSite($uid, $FileList)
        Write-Host "Sucesso"
    }
    catch {
        Write-Error "Falhou ao importar $uid : $_"
    }
}

