# ============================================
# IBM System/34 Theme Installer (perfil: novo-perfil)
# ============================================

Write-Host "A configurar o perfil 'novo-perfil'..." -ForegroundColor Green

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (!(Test-Path $settingsPath)) {
    Write-Host "settings.json não encontrado." -ForegroundColor Red
    exit
}

# Carregar JSON
$json = Get-Content $settingsPath -Raw | ConvertFrom-Json

# Criar secção schemes se não existir
if (-not $json.schemes) {
    $json | Add-Member -MemberType NoteProperty -Name schemes -Value @()
}

# Definir esquema IBM System/34
$ibmScheme = @{
    name = "IBM-System34"
    background = "#000000"
    foreground = "#33FF33"
    cursorColor = "#33FF33"
    selectionBackground = "#003300"
    black = "#000000"
    red = "#33FF33"
    green = "#33FF33"
    yellow = "#33FF33"
    blue = "#33FF33"
    purple = "#33FF33"
    cyan = "#33FF33"
    white = "#33FF33"
    brightBlack = "#003300"
    brightRed = "#66FF66"
    brightGreen = "#66FF66"
    brightYellow = "#66FF66"
    brightBlue = "#66FF66"
    brightPurple = "#66FF66"
    brightCyan = "#66FF66"
    brightWhite = "#99FF99"
}

# Adicionar esquema se não existir
if (-not ($json.schemes | Where-Object { $_.name -eq "IBM-System34" })) {
    $json.schemes += $ibmScheme
}

# Encontrar o perfil "novo-perfil"
$profile = $json.profiles.list | Where-Object { $_.name -eq "novo-perfil" }

if (-not $profile) {
    Write-Host "Perfil 'novo-perfil' não encontrado." -ForegroundColor Red
    exit
}

# Criar propriedades visuais se não existirem
$props = @("colorScheme","fontFace","fontSize","cursorShape","cursorColor","initialRows","initialCols","tabTitle")

foreach ($p in $props) {
    if (-not $profile.PSObject.Properties[$p]) {
        $profile | Add-Member -MemberType NoteProperty -Name $p -Value $null
    }
}

# Aplicar tema
$profile.colorScheme = "IBM-System34"
$profile.fontFace = "Cascadia Mono"
$profile.fontSize = 16
$profile.cursorShape = "filledBox"
$profile.cursorColor = "#33FF33"
$profile.initialRows = 24
$profile.initialCols = 80
$profile.tabTitle = "IBM System/34"

# Guardar ficheiro
$json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8

Write-Host "`nTema IBM System/34 aplicado ao perfil 'novo-perfil'!"
Write-Host "Reinicie o Windows Terminal." -ForegroundColor Green

