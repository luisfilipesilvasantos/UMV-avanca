Write-Output "Fechando o Google Chrome..."
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue

Write-Output "Limpando a cache do Google Chrome..."
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "Cache limpa com sucesso!"
Pause

