$folder = "C:\Users\LuisF\umc-avanca"
$outFolder = "$folder\cleaned"   # pasta separada para não reprocessar os outputs
New-Item -ItemType Directory -Force -Path $outFolder | Out-Null

$patterns = @(
    "edge_all_open_tabs",
    "WebsiteContent_",
    "# User's Edge",
    "The edge_all_open_tabs metadata"
)

Get-ChildItem -Path "$folder\*" -Include *.py, *.txt -File | ForEach-Object {
    $inputFile  = $_.FullName
    $outputFile = Join-Path $outFolder "$($_.BaseName)_utf-8-fix$($_.Extension)"

    Write-Host "Limpando $inputFile -> $outputFile"

    # Ler explicitamente como UTF-8 (evita mojibake em acentos)
    $lines = Get-Content -Path $inputFile -Encoding UTF8

    $clean = $lines | Where-Object {
        $line = $_
        -not ($patterns | Where-Object { $line -match $_ })
    }

    # UTF8 sem BOM (usa Out-File com codificação explícita, ou .NET direto)
    [System.IO.File]::WriteAllLines($outputFile, $clean, [System.Text.UTF8Encoding]::new($false))
}
