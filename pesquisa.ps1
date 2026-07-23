param(
    [Parameter(Mandatory=$true)]
    [string]$Texto,

    [Parameter(Mandatory=$true)]
    [string]$Caminho
)

Write-Host "🔍 A procurar '$Texto' em $Caminho ..." -ForegroundColor Cyan

try {
    $resultados = Select-String -Path "$Caminho\**\*" -Pattern $Texto -ErrorAction SilentlyContinue

    if ($resultados) {
        Write-Host "✔ Encontrado em:" -ForegroundColor Green
        $resultados | Select-Object Path, LineNumber, Line | Format-List
    }
    else {
        Write-Host "❌ Nenhum ficheiro contém o texto especificado." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠ Erro ao procurar. Verifica o caminho ou permissões." -ForegroundColor Red
}
