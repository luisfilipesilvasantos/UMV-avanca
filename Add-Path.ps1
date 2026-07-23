<#
.SYNOPSIS
    Adiciona um ou mais caminhos ao PATH do utilizador de forma persistente e segura.
    Contorna o limite de 1024 caracteres do comando 'setx'.

.EXAMPLE
    .\Add-Path.ps1 "C:\Caminho\Para\Pasta"
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Caminho a adicionar ao PATH")]
    [string[]]$NewPaths
)

# 1) Obter o PATH atual do registo (User level) para evitar poluição da sessão atual
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$pathList = $currentPath -split ";" | Where-Object { $_ -ne "" }

$addedCount = 0

foreach ($p in $NewPaths) {
    # Limpar espaços e aspas
    $cleanPath = $p.Trim().Trim('"')

    if (-not (Test-Path $cleanPath)) {
        Write-Warning "O caminho não existe: $cleanPath"
        continue
    }

    # Verificar se já existe no PATH (case-insensitive)
    if ($pathList -inotcontains $cleanPath) {
        $pathList += $cleanPath
        $addedCount++
        Write-Host "? A adicionar: $cleanPath" -ForegroundColor Cyan
    } else {
        Write-Host "?? Já existe no PATH: $cleanPath" -ForegroundColor Yellow
    }
}

if ($addedCount -gt 0) {
    # Juntar novamente com ponto e vírgula
    $updatedPath = $pathList -join ";"
    
    # Gravar permanentemente no Registo (User)
    [Environment]::SetEnvironmentVariable("PATH", $updatedPath, "User")
    
    # Atualizar a sessão atual do PowerShell para uso imediato
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + $updatedPath
    
    Write-Host "`n? Sucesso! $addedCount caminho(s) adicionado(s) ao PATH permanentemente." -ForegroundColor Green
    Write-Host "?? Nota: Novas consolas terão o PATH atualizado. A sessão atual foi atualizada para este processo."
} else {
    Write-Host "`nNada a alterar. O PATH já contém os caminhos indicados." -ForegroundColor Gray
}



