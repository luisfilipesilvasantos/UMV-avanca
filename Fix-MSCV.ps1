# Fix-MSCV.ps1
# Corrige erro "cl.exe não encontrado" configurando ambiente MSVC automaticamente

Write-Host "`n=== MSVC Auto-Fix ===`n"

# 1) Procurar instalação do MSVC usando vswhere (mais robusto)
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installPath = $null

if (Test-Path $vswhere) {
    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}

if (-not $installPath) {
    # Fallback para caminhos manuais (incluindo VS 18/2022)
    $vsPaths = @(
        "C:\Program Files\Microsoft Visual Studio\18\Community",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools",
        "C:\Program Files\Microsoft Visual Studio\2022\Community",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community"
    )

    foreach ($p in $vsPaths) {
        if (Test-Path (Join-Path $p "VC\Auxiliary\Build\vcvarsall.bat")) {
            $installPath = $p
            break
        }
    }
}

if (-not $installPath) {
    Write-Host "❌ MSVC não encontrado no sistema."
    Write-Host "➡ A abrir instalador Build Tools..."
    Start-Process "https://aka.ms/vs/17/release/vs_BuildTools.exe"
    exit
}

$vcvars = Join-Path $installPath "VC\Auxiliary\Build\vcvarsall.bat"
Write-Host "�... MSVC encontrado em: $installPath"

# 2) Criar wrapper temporário para carregar ambiente MSVC
$temp = "$env:TEMP\msvc_env.cmd"
@"
@echo off
call "$vcvars" x64 >nul
set
"@ | Out-File -Encoding ascii $temp

# 3) Executar wrapper e capturar variáveis
$vars = cmd.exe /c $temp

Write-Host "�"� A configurar variáveis de ambiente (pode demorar alguns segundos)..."
foreach ($line in $vars) {
    if ($line -match "^(.*?)=(.*)$") {
        $name = $matches[1]
        $value = $matches[2]

        # Apenas atualizar variáveis críticas para evitar poluição excessiva do registo
        if ($name -in @("PATH", "INCLUDE", "LIB", "LIBPATH")) {
            [Environment]::SetEnvironmentVariable($name, $value, "User")
            # Também atualizar a sessão atual
            Set-Content "env:$name" $value
        }
    }
}

Write-Host "✨ Ambiente MSVC configurado!"

# 4) Testar cl.exe
$cl = Get-Command cl.exe -ErrorAction SilentlyContinue

if ($cl) {
    Write-Host "🚀 Sucesso! O cl.exe está disponível em:"
    Write-Host "   $($cl.Source)"
} else {
    Write-Host "⚠️ O MSVC foi configurado, mas pode ser necessário reiniciar a consola para aplicar o PATH totalmente."
}


