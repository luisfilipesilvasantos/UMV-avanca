param(
    [Parameter(Mandatory=$true)]
    [string]$InputVideo,

    [Parameter(Mandatory=$false)]
    [string]$OutputVideo = "output_10s.mp4"
)

# Verifica se o FFmpeg está instalado
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "FFmpeg não encontrado no PATH. Instale o FFmpeg ou adicione-o ao PATH." -ForegroundColor Red
    exit 1
}

# Executa o crop para 10 segundos
ffmpeg -i "$InputVideo" -ss 0 -t 10 -c copy "$OutputVideo"

Write-Host "Vídeo cortado para 10 segundos com sucesso!" -ForegroundColor Green
Write-Host "Arquivo gerado: $OutputVideo"

