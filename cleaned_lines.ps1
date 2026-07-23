$folder = "C:\Users\LuisF\umc-avanca"

# Pega todos os .py e .txt da pasta
Get-ChildItem -Path $folder -Include *.py, *.txt -File | ForEach-Object {
    $inputFile = $_.FullName
    $outputFile = "$($folder)\$($_.BaseName)_utf-8-fix.txt"

    Write-Host "Limpando $inputFile -> $outputFile"

    Get-Content $inputFile | ForEach-Object {
        # Remove linhas com metadados do Edge
        if ($_ -notmatch "edge_all_open_tabs" -and `
            $_ -notmatch "WebsiteContent_" -and `
            $_ -notmatch "# User's Edge" -and `
            $_ -notmatch "The edge_all_open_tabs metadata") {
            $_
        }
    } | Set-Content $outputFile -Encoding UTF8
}
