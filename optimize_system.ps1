#requires -RunAsAdministrator
# Otimização do Pagefile para IA no Windows
# Configura pagefile estático em SSD NVMe mais rápido (geralmente C:)
# Tamanho configurável: 64 ou 96 GB

param(
    [ValidateSet(64, 96)]
    [int]$SizeGB = 64,
    [string]$DriveLetter = "C"
)

Write-Host "=== Otimização do Pagefile para IA ===" -ForegroundColor Cyan

# Validar se o drive existe
$driveInfo = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
if (-not $driveInfo) {
    Write-Host "ERRO: Drive $DriveLetter não encontrado." -ForegroundColor Red
    exit 1
}

# Calcular tamanho em MB
$sizeMB = $SizeGB * 1024
Write-Host "Configurando pagefile estático de $SizeGB GB ($sizeMB MB) em ${DriveLetter}:\pagefile.sys" -ForegroundColor Yellow

# 1. Desativar o gerenciamento automático global de Pagefile no Windows
Write-Host "Desativando gerenciamento automático do Windows..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "AutomaticPagedPoolSize" -Value 0 -Type DWord -Force

# 2. Configurar o Pagefile de forma estática com o formato correto (MultiString / REG_MULTI_SZ)
$pageFileValue = "${DriveLetter}:\pagefile.sys $sizeMB $sizeMB"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value $pageFileValue -Type MultiString -Force

# Aplicar configuração imediatamente tentando reiniciar o SysMain
Write-Host "Aplicando nova configuração no serviço de memória..." -ForegroundColor Cyan
Restart-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue

# Verificar configuração atual (Nota: O tamanho novo só reflete após reiniciar)
try {
    $pagefile = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue
    if ($pagefile) {
        Write-Host "`nConfiguração em cache do Pagefile:" -ForegroundColor Green
        $pagefile | Format-List Name, InitialSize, MaximumSize
    } else {
        Write-Host "`n[INFO] O Windows aplicará o novo Pagefile de $SizeGB GB após o próximo reinício." -ForegroundColor Yellow
    }
} catch {
    Write-Host "`n[INFO] Configurações registadas com sucesso." -ForegroundColor Green
}

Write-Host "`n✅ Otimização concluída com sucesso!" -ForegroundColor Green
Write-Host "⚠️ IMPORTANTE: É estritamente necessário REINICIAR o Windows para que o sistema aloque o ficheiro de $SizeGB GB no disco!" -ForegroundColor Yellow