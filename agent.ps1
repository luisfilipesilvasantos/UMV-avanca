param(
    [string]$prompt
)

# 1. Envia pedido ao Qwen
$response = Invoke-WebRequest -Uri "http://localhost:11434/api/generate" `
  -Method POST `
  -Body "{""model"":""qwen2.5-coder:7b-instruct"",""prompt"":""$prompt"",""stream"":false}" `
  -ContentType "application/json"

# 2. Extrai texto
$json = $response.Content | ConvertFrom-Json
$code = $json.response

# 3. Guarda o código num ficheiro
Set-Content -Path ".\output.txt" -Value $code

# 4. Se Qwen gerar comandos PowerShell, executa-os
if ($code -match "powershell") {
    Write-Host "Executando comandos..."
    Invoke-Expression $code
}

Write-Host "Resposta guardada em output.txt"

