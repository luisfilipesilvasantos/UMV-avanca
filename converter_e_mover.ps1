# Define o caminho principal
$diretorio = "C:\Users\luisf"
$subpasta = Join-Path $diretorio "c-backup"

# Cria a pasta c-backup se ela não existir
if (!(Test-Path $subpasta)) {
    New-Item -ItemType Directory -Path $subpasta
}

# Obtém todos os arquivos .bat no diretório
$arquivosBat = Get-ChildItem -Path $diretorio -Filter *.bat

foreach ($arquivo in $arquivosBat) {
    # Lê o conteúdo do arquivo .bat
    $conteudo = Get-Content -Path $arquivo.FullName -Raw

    # Verifica se o conteúdo contém a palavra "powershell"
    # Isso identifica se o .bat está executando um comando PowerShell
    if ($conteudo -match "powershell") {
        
        # Define o nome do novo arquivo .ps1
        $nomePs1 = $arquivo.BaseName + ".ps1"
        $caminhoPs1 = Join-Path $diretorio $nomePs1

        # Converte o conteúdo: 
        # Remove o prefixo "powershell -Command" ou "powershell -c" para deixar apenas o comando puro
        $conteudoLimpo = $conteudo -replace "powershell.*-Command\s*", ""
        $conteudoLimpo = $conteudoLimpo -replace '"', "" -replace "'", ""
        
        # Salva o novo arquivo .ps1
        $conteudoLimpo | Out-File -FilePath $caminhoPs1 -Encoding utf8
        Write-Host "Convertido: $($arquivo.Name) -> $nomePs1" -ForegroundColor Cyan
    }
    else {
        Write-Host "CMD puro: $($arquivo.Name) (Apenas movendo...)" -ForegroundColor Yellow
    }

    # Move o arquivo .bat original para a subpasta c-backup
    Move-Item -Path $arquivo.FullName -Destination (Join-Path $subpasta $arquivo.Name)
}

Write-Host "Concluído!" -ForegroundColor Green

