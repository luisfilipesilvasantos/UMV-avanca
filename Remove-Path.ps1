<#
.SYNOPSIS
    Remove um ou mais caminhos do PATH do utilizador de forma persistente e segura.
    Garante a integridade do PATH sem os limites do comando 'setx'.

.EXAMPLE
    .\Remove-Path.ps1 "C:\Caminho\Para\Remover"
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Caminho a remover do PATH")]
    [string[]]$PathsToRemove
)

# 1) Obter o PATH atual do registo (User level)
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if (-not $currentPath) {
    Write-Error "Não foi possível obter o PATH do utilizador ou o PATH está vazio."
    exit
}

$pathList = $currentPath -split ";" | Where-Object { $_ -ne "" }
$originalCount = $pathList.Count
$newPathList = @()

# Criar lista de caminhos a remover limpos
$cleanRemovals = $PathsToRemove | ForEach-Object { $_.Trim().Trim('"').TrimEnd('\') }

foreach ($p in $pathList) {
    $cleanP = $p.Trim().TrimEnd('\')
    
    # Se o caminho atual não estiver na lista de remoção, mantém-se
    $match = $false
    foreach ($rem in $cleanRemovals) {
        if ($cleanP -ieq $rem) {
            $match = $true
            break
        }
    }
    
    if (-not $match) {
        $newPathList += $p
    } else {
        Write-Host "�-'️ A remover: $p" -ForegroundColor Yellow
    }
}

$removedCount = $originalCount - $newPathList.Count

if ($removedCount -gt 0) {
    # Juntar novamente
    $updatedPath = $newPathList -join ";"
    
    # Gravar permanentemente no Registo (User)
    [Environment]::SetEnvironmentVariable("PATH", $updatedPath, "User")
    
    # Atualizar a sessão atual
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + $updatedPath
    
    Write-Host "`n✨ Sucesso! $removedCount caminho(s) removido(s) do PATH permanentemente." -ForegroundColor Green
    Write-Host "�"� Nota: Novas consolas refletirão a mudança. A sessão atual foi atualizada."
} else {
    Write-Host "`nNada a remover. Os caminhos indicados não foram encontrados no PATH do utilizador." -ForegroundColor Gray
}

