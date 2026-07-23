$ErrorActionPreference = "Continue"

Write-Host "=== RESUMO DO DISCO C: ===" -ForegroundColor Cyan
Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | ForEach-Object {
    $sizeGB = [math]::Round($_.Size/1GB,2)
    $freeGB = [math]::Round($_.FreeSpace/1GB,2)
    $usedGB = [math]::Round(($_.Size-$_.FreeSpace)/1GB,2)
    $pctFree = [math]::Round(($_.FreeSpace/$_.Size)*100,1)
    Write-Host "Total: $sizeGB GB | Usado: $usedGB GB | Livre: $freeGB GB ($pctFree% livre)"
}

Write-Host "`n=== TOP 25 PASTAS EM C:\ (por tamanho) ===" -ForegroundColor Cyan
Get-ChildItem -Path C:\ -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('$Recycle.Bin','System Volume Information','Recovery') } |
    ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        [PSCustomObject]@{
            SizeGB = [math]::Round($size/1GB,2)
            Path   = $_.FullName
        }
    } | Sort-Object SizeGB -Descending | Select-Object -First 25 | Format-Table -AutoSize

Write-Host "`n=== CACHES E TEMPORARIOS COMUNS (estimativa) ===" -ForegroundColor Cyan
$targets = @(
    @{Path="$env:TEMP"; Label="Temp do utilizador"},
    @{Path="$env:TMP";  Label="TMP do utilizador"},
    @{Path="C:\Windows\Temp"; Label="Windows Temp"},
    @{Path="C:\Windows\Prefetch"; Label="Prefetch"},
    @{Path="C:\Windows\SoftwareDistribution\Download"; Label="Windows Update Downloads"},
    @{Path="C:\ProgramData\Microsoft\Windows\WER"; Label="Windows Error Reports"},
    @{Path="$env:LOCALAPPDATA\CrashDumps"; Label="Crash Dumps"},
    @{Path="$env:LOCALAPPDATA\NVIDIA\DXCache"; Label="NVIDIA DXCache"},
    @{Path="$env:LOCALAPPDATA\pip\cache"; Label="pip cache"},
    @{Path="$env:LOCALAPPDATA\NuGet\Cache"; Label="NuGet cache"},
    @{Path="$env:LOCALAPPDATA\ms-playwright"; Label="Playwright browsers"},
    @{Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; Label="Chrome Cache"},
    @{Path="C:\Users\luisf\.cache"; Label="Cache geral (.cache)"},
    @{Path="C:\Users\luisf\.npm\_cacache"; Label="npm cache"},
    @{Path="C:\Users\luisf\AppData\Local\Temp"; Label="AppData\\Local\\Temp"},
    @{Path="C:\Users\luisf\AppData\Local\CrashDumps"; Label="AppData CrashDumps"},
    @{Path="C:\$Recycle.Bin"; Label="Recycle Bin (raiz)"},
    @{Path="C:\hiberfil.sys"; Label="Hiberfile (sys)"},
    @{Path="C:\pagefile.sys"; Label="Pagefile (sys)"},
    @{Path="C:\swapfile.sys"; Label="Swapfile (sys)"}
)

foreach ($t in $targets) {
    if (Test-Path $t.Path) {
        $size = (Get-ChildItem -Path $t.Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $sizeGB = [math]::Round($size/1GB,2)
        $sizeMB = [math]::Round($size/1MB,1)
        $disp = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }
        Write-Host ("{0,-45} {1,10}" -f $t.Label, $disp)
    } else {
        Write-Host ("{0,-45} {1,10}" -f $t.Label, "(nao existe)") -ForegroundColor DarkGray
    }
}

Write-Host "`n=== PASTAS GRANDES NO PERFIL DO UTILIZADOR ===" -ForegroundColor Cyan
Get-ChildItem -Path $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
    ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        [PSCustomObject]@{
            SizeGB = [math]::Round($size/1GB,2)
            Path   = $_.FullName
        }
    } | Sort-Object SizeGB -Descending | Select-Object -First 20 | Format-Table -AutoSize

Write-Host "`n=== LIXO DO SISTEMA / LOGS ANTIGOS ===" -ForegroundColor Cyan
Write-Host "Tamanho de C:\Windows\Logs:"
$logSize = (Get-ChildItem C:\Windows\Logs -Recurse -Force -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
Write-Host ("  {0:N2} GB" -f ($logSize/1GB))

Write-Host "Tamanho de C:\Windows\Installer (msi patches):"
$msiSize = (Get-ChildItem C:\Windows\Installer -Recurse -Force -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
Write-Host ("  {0:N2} GB" -f ($msiSize/1GB))

Write-Host "Tamanho de C:\Windows\WinSxS:"
$winsxsSize = (Get-ChildItem C:\Windows\WinSxS -Recurse -Force -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
Write-Host ("  {0:N2} GB" -f ($winsxsSize/1GB))

Write-Host "`n=== CONCLUIDO ===" -ForegroundColor Green

