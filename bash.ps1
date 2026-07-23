# Caminho para o executável do Git Bash
$gitBash = "C:\Program Files\Git\bin\bash.exe"

# Diretório onde o comando foi executado
$cwd = (Get-Location).Path

# Abre o Git Bash nesse diretório
Start-Process -FilePath $gitBash -WorkingDirectory $cwd

