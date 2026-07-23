<#
.SYNOPSIS
    Corrige o conflito da política ContextCluesEnabled no Microsoft Edge
    e verifica se existem políticas a bloquear o Copilot.

.NOTES
    - Corre este script com "Run as Administrator" (botão direito -> Executar como administrador)
      para que a parte de HKLM funcione. Sem admin, a parte de HKCU ainda funciona.
    - Não mexe em nada fora de HKCU/HKLM\SOFTWARE\Policies\Microsoft\Edge.
    - Não apaga pastas do sistema (System32\GroupPolicy). Isso NUNCA é necessário aqui.
#>

$ErrorActionPreference = "SilentlyContinue"

function Write-Section($title) {
    Write-Host ""
    Write-Host "==== $title ====" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# 0. Verificar se está a correr como admin
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "AVISO: Não estás a correr como Administrador." -ForegroundColor Yellow
    Write-Host "A parte HKLM pode falhar. Recomendado: fecha e volta a abrir como Admin." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 1. Fechar o Edge por completo (para não haver cache de políticas antigas)
# ---------------------------------------------------------------------------
Write-Section "A fechar o Microsoft Edge"
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Write-Host "Edge fechado (se estava aberto)."

# ---------------------------------------------------------------------------
# 2. Remover ContextCluesEnabled de HKLM (fonte do conflito "Unknown policy")
# ---------------------------------------------------------------------------
Write-Section "HKLM - remover valor conflituoso"
$hklmPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

if (Test-Path $hklmPath) {
    $val = Get-ItemProperty -Path $hklmPath -Name "ContextCluesEnabled" -ErrorAction SilentlyContinue
    if ($val) {
        Remove-ItemProperty -Path $hklmPath -Name "ContextCluesEnabled" -Force
        Write-Host "Removido ContextCluesEnabled de HKLM." -ForegroundColor Green
    } else {
        Write-Host "Não existia ContextCluesEnabled em HKLM (ok)." -ForegroundColor Green
    }
} else {
    Write-Host "Chave HKLM\SOFTWARE\Policies\Microsoft\Edge não existe (ok)." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. Garantir ContextCluesEnabled = 1 em HKCU
# ---------------------------------------------------------------------------
Write-Section "HKCU - garantir valor correto"
$hkcuPath = "HKCU:\SOFTWARE\Policies\Microsoft\Edge"

if (-not (Test-Path $hkcuPath)) {
    New-Item -Path $hkcuPath -Force | Out-Null
}
New-ItemProperty -Path $hkcuPath -Name "ContextCluesEnabled" -PropertyType DWord -Value 1 -Force | Out-Null
Write-Host "ContextCluesEnabled = 1 confirmado em HKCU." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Verificar se existe ficheiro de políticas geridas (managed policies)
# ---------------------------------------------------------------------------
Write-Section "A verificar ficheiros de políticas geridas"
$managedPath = "C:\ProgramData\Microsoft\Edge\Policies\Managed"

if (Test-Path $managedPath) {
    Write-Host "Encontrada pasta de políticas geridas:" -ForegroundColor Yellow
    Get-ChildItem $managedPath | ForEach-Object {
        Write-Host " - $($_.FullName)"
        Get-Content $_.FullName -Raw | Select-String "ContextCluesEnabled|CopilotPageContext|BrowsingWithCopilot" | ForEach-Object {
            Write-Host "   >> $_" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "Não existe pasta de políticas geridas (ok, nada a limpar aqui)." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 5. Diagnóstico das políticas relacionadas com o Copilot
# ---------------------------------------------------------------------------
Write-Section "Diagnóstico de políticas do Copilot (HKLM + HKCU)"
$copilotPolicies = @(
    "CopilotPageContextEnabled",
    "CopilotPageContext",
    "AllowBrowsingWithCopilot",
    "BrowsingWithCopilotBlockList",
    "BrowsingWithCopilotAllowList",
    "ShareBrowsingHistoryWithCopilotSearchAllowed",
    "ContextCluesEnabled"
)

foreach ($root in @("HKLM:\SOFTWARE\Policies\Microsoft\Edge", "HKCU:\SOFTWARE\Policies\Microsoft\Edge")) {
    Write-Host ""
    Write-Host "[$root]"
    foreach ($p in $copilotPolicies) {
        $v = Get-ItemProperty -Path $root -Name $p -ErrorAction SilentlyContinue
        if ($v) {
            Write-Host "  $p = $($v.$p)"
        } else {
            Write-Host "  $p = (not set)"
        }
    }
}

# ---------------------------------------------------------------------------
# 6. Reabrir o Edge em edge://policy para confirmação visual
# ---------------------------------------------------------------------------
Write-Section "A reabrir o Edge em edge://policy"
Start-Process "msedge.exe" "edge://policy"

Write-Host ""
Write-Host "Concluído. No edge://policy que acabou de abrir, clica em 'Reload Policies'" -ForegroundColor Cyan
Write-Host "e confirma que ContextCluesEnabled aparece sem Warning/Conflict/Error." -ForegroundColor Cyan
Write-Host "Depois testa o Copilot numa página normal." -ForegroundColor Cyan
