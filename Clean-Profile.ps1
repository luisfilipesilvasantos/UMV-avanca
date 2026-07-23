$profilePath = $PROFILE

$lines = Get-Content $profilePath

$edgeNoisePatterns = @(
    "edge_all_open_tabs",
    "WebsiteContent_",
    "User's Edge browser tabs metadata",
    "tabId",
    "isCurrent"
)

$cleanLines = $lines | Where-Object {
    $line = $_
    -not ($edgeNoisePatterns | ForEach-Object { $line -match $_ })
}

Set-Content -Path $profilePath -Value $cleanLines -Encoding UTF8

Write-Host "Perfil limpo com sucesso."

