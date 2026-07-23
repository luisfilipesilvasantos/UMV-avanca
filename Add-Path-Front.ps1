<#
.SYNOPSIS
Adiciona um caminho ao INÍCIO do PATH do utilizador (persistente).
Usado para sobrepor aliases do Windows (ex: python.exe da Microsoft Store).

.EXAMPLE
.\Add-Path-Front.ps1 "C:\Users\luisf\bin"
#>

param (
    [Parameter(Mandatory=$true)]
    [string[]]$NewPaths
)

$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$pathList = $currentPath -split ";" | Where-Object { $_ -ne "" }
$addedCount = 0

foreach ($p in $NewPaths) {
    $cleanPath = $p.Trim().Trim('"')
    if (-not (Test-Path $cleanPath)) {
        Write-Warning "O caminho não existe: $cleanPath"
        continue
    }
    if ($pathList -inotcontains $cleanPath) {
        # Inserir no início
        $pathList = @($cleanPath) + $pathList
        $addedCount++
        Write-Host "�... Adicionado ao INÍCIO: $cleanPath" -ForegroundColor Cyan
    } else {
        # Mover para o início se já existir
        $pathList = @($cleanPath) + ($pathList | Where-Object { $_ -ine $cleanPath })
        Write-Host "ℹ️ Movido para o INÍCIO (já existia): $cleanPath" -ForegroundColor Yellow
    }
}

if ($addedCount -gt 0 -or $true) {
    $updatedPath = $pathList -join ";"
    [Environment]::SetEnvironmentVariable("PATH", $updatedPath, "User")
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + $updatedPath
    Write-Host "`n✨ PATH atualizado. Novas consolas vão usar o novo caminho." -ForegroundColor Green
}

