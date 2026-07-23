# Ativar .NET Framework 3.5 e 4.x no Windows
# Criado a partir da configuração "WPFFeaturesdotnet"

Write-Host "A ativar .NET Framework 3.5 e 4.x..." -ForegroundColor Cyan

$features = @(
    "NetFx4-AdvSrvs",
    "NetFx3"
)

foreach ($feature in $features) {
    Write-Host "A ativar feature: $feature" -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
}

Write-Host "Processo concluído. Reinicia o sistema se necessário." -ForegroundColor Green

