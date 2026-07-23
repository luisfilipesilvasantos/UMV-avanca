<#
.SYNOPSIS
    build_tool - Compilador modular para múltiplas linguagens.

.DESCRIPTION
    Detecta automaticamente o tipo de projeto e compila usando o comando
    adequado. Suporta: Rust, Python, C, C++, Go, JavaScript/Node, TypeScript, Java.
#>

$BuildToolVersion = "1.0.0"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

Function Global:Detect-Language {
    <#
    .DESCRIPTION
        Detecta automaticamente a linguagem do projeto analisando arquivos de configuração.
    #>
    Param(
        [string]$Path
    )

    # Verificar arquivos de configuração comuns
    $configFiles = @(
        "Cargo.toml",
        "package.json",
        "pkg.json",
        "setup.py",
        "pyproject.toml",
        "CMakeLists.txt",
        "CMakeLists",
        "Makefile",
        "Gopkg.toml",
        "go.mod",
        "build.gradle",
        "build.gradle.kts",
        "pom.xml",
        "build.pom.xml",
        ".csproj",
        ".vbproj",
        ".fsproj",
        ".psm1",
        "Rakefile",
        "Gemfile"
    )

    foreach ($cfg in $configFiles) {
        $cfgPath = Join-Path $Path $cfg
        if (Test-Path $cfgPath) {
            # Determinar linguagem baseado no arquivo
            switch ($cfg) {
                "Cargo.toml" { return "Rust" }
                "setup.py" { return "Python" }
                "pyproject.toml" { return "Python" }
                "Gopkg.toml" { return "Rust" }
                "go.mod" { return "Go" }
                "build.gradle" { return "Java" }
                "build.gradle.kts" { return "Java" }
                "pom.xml" { return "Java" }
                "build.pom.xml" { return "Java" }
                "build.gradle.kts" { return "Java" }
                ".vbproj" { return "VB.NET" }
                ".csproj" { return "C#" }
                ".fsproj" { return "F#" }
                ".psm1" { return "PowerShell" }
                default { return "C" }
            }
        }
    }

    # Fallback: tentar detectar pelo conteúdo de arquivos fonte
    $sourcePatterns = @{
        "*.rs" = "Rust"
        "*.py" = "Python"
        "*.c" = "C"
        "*.cpp" = "C++"
        "*.h" = "C++"
        "*.go" = "Go"
        "*.java" = "Java"
        "*.ts" = "TypeScript"
        "*.tsx" = "TypeScript"
        "*.js" = "JavaScript"
        "*.cs" = "C#"
        "*.vb" = "VB.NET"
        "*.fs" = "F#"
    }

    foreach ($pair in $sourcePatterns.GetEnumerator()) {
        $pattern = $pair.Key
        $lang = $pair.Value
        $files = Get-ChildItem -Path $Path -Include $pattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($files) {
            return $lang
        }
    }

    return "Unknown"
}

Function Global:Get-Compiler {
    <#
    .DESCRIPTION
        Retorna o comando e argumentos do compilador adequado para cada linguagem.
    #>
    Param(
        [string]$Language,
        [string]$SourceFile,
        [string]$OutputFile
    )

    $compilers = @{
        "Rust" = @{
            Command = "cargo"
            Args = "build"
            Source = "Cargo.toml"
            Output = "target/debug/"
            Executable = "debug/<name>"
        }
        "Python" = @{
            Command = "pip"
            Args = "install -e ."
            Source = "setup.py"
            Output = "dist/"
            Executable = "app.exe"
        }
        "JavaScript" = @{
            Command = "npm"
            Args = "run build"
            Source = "package.json"
            Output = "dist/"
            Executable = "dist/<name>.js"
        }
        "TypeScript" = @{
            Command = "npm"
            Args = "run build"
            Source = "package.json"
            Output = "dist/"
            Executable = "dist/<name>.js"
        }
        "C" = @{
            Command = "gcc"
            Args = "-o $OutputFile $SourceFile"
            Output = "output.exe"
        }
        "C++" = @{
            Command = "g++"
            Args = "-o $OutputFile $SourceFile"
            Output = "output.exe"
        }
        "Go" = @{
            Command = "go"
            Args = "build -o $OutputFile ./"
            Output = "output.exe"
        }
        "Java" = @{
            Command = "mvn"
            Args = "package"
            Source = "pom.xml"
            Output = "target/"
            Executable = "target/<artifact>-jar-dependencies.jar"
        }
        "VB.NET" = @{
            Command = "dotnet"
            Args = "build"
            Source = ".vbproj"
            Output = "bin/"
            Executable = "bin/<name>.dll"
        }
        "C#" = @{
            Command = "dotnet"
            Args = "build"
            Source = ".csproj"
            Output = "bin/"
            Executable = "bin/<name>.dll"
        }
        "F#" = @{
            Command = "dotnet"
            Args = "build"
            Source = ".fsproj"
            Output = "bin/"
            Executable = "bin/<name>.dll"
        }
        "PowerShell" = @{
            Command = "pwsh"
            Args = "-NoProfile -ExecutionPolicy Bypass"
            Source = "*.ps1"
            Output = "bin/"
            Executable = "bin/<name>.ps1"
        }
        "Ruby" = @{
            Command = "bundle"
            Args = "exec rake"
            Source = "Rakefile"
            Output = "bin/"
            Executable = "bin/<name>"
        }
    }

    if ($compilers.ContainsKey($Language)) {
        $comp = $compilers[$Language]
        return $comp
    }

    return @{ Command="unknown"; Args="" }
}

Function Global:Check-Compiler-Available {
    <#
    .DESCRIPTION
        Verifica se um compilador/interpreter está disponível no sistema.
    #>
    Param(
        [string]$Compiler
    )

    try {
        $version = & $Compiler --version 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

Function Global:Find-Compiler {
    <#
    .DESCRIPTION
        Tenta encontrar o compilador em diferentes locais.
    #>
    Param(
        [string]$Compiler
    )

    # Tentar sem caminho primeiro
    if (Test-Path $Compiler) {
        return $Compiler
    }

    # Tentar em PATH
    try {
        $compilerInPath = $null
        if ($Compiler -eq "python" -or $Compiler -eq "python3") {
            # Python pode estar em múltiplos locais
            foreach ($pyPath in @("python", "python3", "C:\Python*Python.exe", "C:\Python*python.exe")) {
                if (Test-Path $pyPath) { return $pyPath }
            }
        } elseif ($Compiler -eq "npm" -or $Compiler -eq "node") {
            foreach ($nodePath in @("node", "C:\Program Files\nodejs\node.exe", "C:\npm\node.exe")) {
                if (Test-Path $nodePath) { return $nodePath }
            }
        } elseif ($Compiler -eq "cargo" -or $Compiler -eq "rustc") {
            foreach ($rustPath in @("cargo", "rustc", "C:\Program Files\rga\cargo.exe", "C:\Program Files\rga\rustc.exe", "$env:LOCALAPPDATA\Programs\rust", "C:\msys64\mingw64\bin", "C:\msys64\usr\bin")) {
                if (Test-Path $rustPath) { return $rustPath }
            }
        } elseif ($Compiler -eq "gcc" -or $Compiler -eq "g++" -or $Compiler -eq "clang") {
            foreach ($gccPath in @("gcc", "g++", "clang", "clang++", "C:\Program Files\LLVM\bin", "C:\MinGW\bin", "$env:PATH")) {
                try {
                    if (Test-Path $gccPath) { return $gccPath }
                } catch {}
            }
        } elseif ($Compiler -eq "go") {
            foreach ($goPath in @("go", "C:\Program Files\go\go.exe", "$env:GOROOT\bin\go.exe")) {
                if (Test-Path $goPath) { return $goPath }
            }
        } elseif ($Compiler -eq "mvn") {
            foreach ($mvnPath in @("mvn", "C:\Program Files\Apache Maven\bin\mvn.cmd", "C:\Program Files\Apache Maven3\bin\mvn.cmd")) {
                if (Test-Path $mvnPath) { return $mvnPath }
            }
        } elseif ($Compiler -eq "dotnet") {
            if (Test-Path "dotnet") { return "dotnet" }
        }
    } catch {}

    return $null
}

Function Global:Parse-Project-Config {
    <#
    .DESCRIPTION
        Extrai informações de configuração de projeto.
    #>
    Param(
        [string]$Path,
        [string]$ConfigFile
    )

    $configPath = Join-Path $Path $ConfigFile

    if (-not (Test-Path $configPath)) {
        return $null
    }

    try {
        # Tentar JSON primeiro
        $config = Get-Content $configPath -ErrorAction SilentlyContinue | ConvertFrom-Json

        return @{
            Name          = $config.name
            Version       = $config.version
            Output        = $config.output
            MainFile      = $config.main || $config.entry
            Source        = $config.source || $config.src
            Dependencies  = $config.dependencies
            Scripts       = $config.scripts
        }
    } catch {
        # Tentar XML para projetos .NET
        if ($configPath -like "*.xml") {
            return @{
                Name = $config.productname
                Version = $config.version
            }
        }

        return $null
    }
}

Function Global:Format-Build-Result {
    <#
    .DESCRIPTION
        Cria um objeto de resultado estruturado para build.
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Status,       # success, fail, partial

        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$true)]
        [double]$Duration,

        [string]$OutputPath = $null,

        [string]$Errors = $null,

        [string]$Warnings = $null
    )

    $result = [PSCustomObject] @{
        Status      = $Status
        Command     = $Command
        Duration    = $Duration
        OutputPath  = $OutputPath
        Errors      = $Errors
        Warnings    = $Warnings
        Timestamp   = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        Language    = "unknown"
        Mode        = "compile"
    }

    return $result
}

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================

Function Global:Build-Project {
    <#
    .SYNOPSIS
        Compila um projeto detectando automaticamente a linguagem.

    .DESCRIPTION
        Detecta o tipo de projeto, verifica ferramentas necessárias,
        executa compilação e retorna resultado estruturado.

    .PARAMETER Path
        Caminho para o diretório do projeto a compilar.

    .PARAMETER Output
        Caminho de saída do executável ou bundle gerado.

    .PARAMETER Mode
        Modo de operação:
        - compile: compila padrão
        - bundle: cria executável bundlado
        - lint: executa análise estática
        - clean: limpa diretórios de build
        - test: executa testes

    .PARAMETER Quiet
        Modo silencioso - minimiza output durante o build.

    .PARAMETER Verbose
        Mostra mais detalhes durante o processo de compilação.

    .EXAMPLE
        Build-Project -Path "C:\myproject"

    .EXAMPLE
        Build-Project -Path "C:\rustproject" -Mode "bundle" -Output "dist\app.exe"
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$Output,

        [string]$Mode = "compile",

        [switch]$Quiet,

        [switch]$Verbose
    )

    $startTime = Get-Date
    $results = [PSCustomObject]@{
        Status     = "fail"
        Command    = "unknown"
        Duration   = 0
        OutputPath = $null
        Errors     = $null
        Warnings   = $null
        Language   = "unknown"
        Mode       = $Mode
        Timestamp  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    begin {
        if ($Verbose) {
            Write-Host "`n=== BUILD TOOL $BuildToolVersion ===" -ForegroundColor Cyan
            Write-Host "Project Path: $Path" -ForegroundColor Yellow
            Write-Host "Mode: $Mode" -ForegroundColor Yellow
        }
    }

    process {
        # Validar caminho
        if (-not (Test-Path $Path)) {
            if ($Quiet) {
                $results.Status = "fail"
                $results.Errors = "Project path does not exist: $Path"
                return $results
            }
            Write-Host "❌ Error: Project path does not exist: $Path" -ForegroundColor Red
            return $results
        }

        # Detectar linguagem
        $language = Detect-Language -Path $Path
        $results.Language = $language

        if ($language -eq "Unknown") {
            if (-not $Quiet) {
                Write-Host "❌ Error: Could not detect project language. Supported: Rust, Python, C, C++, Go, JavaScript, TypeScript, Java, Ruby, VB.NET, C#, F#, PowerShell" -ForegroundColor Red
            }
            $results.Errors = "Could not detect project language. Supported: Rust, Python, C, C++, Go, JavaScript, TypeScript, Java, Ruby, VB.NET, C#, F#, PowerShell"
            return $results
        }

        if (-not $Quiet) {
            Write-Host "�... Detected project language: $language" -ForegroundColor Green
        }

        # Encontrar arquivo de configuração principal
        $configFile = $null
        $config = $null

        switch ($language) {
            "Rust" { $configFile = "Cargo.toml" }
            "Python" { $configFile = "setup.py"; $altConfig = "pyproject.toml" }
            "JavaScript" { $configFile = "package.json" }
            "TypeScript" { $configFile = "package.json" }
            "C" { $configFile = "Makefile" }
            "C++" { $configFile = "CMakeLists.txt" }
            "Go" { $configFile = "go.mod" }
            "Java" { $configFile = "pom.xml"; $altConfig = "build.gradle" }
            "Ruby" { $configFile = "Rakefile" }
            "VB.NET" { $configFile = ".vbproj" }
            "C#" { $configFile = ".csproj" }
            "F#" { $configFile = ".fsproj" }
            "PowerShell" { $configFile = "*.psm1" }
        }

        # Verificar arquivo de configuração
        $fullConfigPath = Join-Path $Path $configFile
        if (-not (Test-Path $fullConfigPath)) {
            if (-not $Quiet) {
                Write-Host "⚠️ Warning: Config file not found: $configFile" -ForegroundColor Yellow
            }
        } else {
            $config = Parse-Project-Config -Path $Path -ConfigFile $configFile
        }

        # Modo clean
        if ($Mode -eq "clean") {
            if (-not $Quiet) {
                Write-Host "🧹 Cleaning build artifacts..." -ForegroundColor Cyan
            }

            # Identificar diretórios de build
            $buildDirs = @(
                "target",           # Rust, .NET
                "build",            # C/C++
                "dist",             # JavaScript
                "bin",              # .NET
                "__pycache__",      # Python
                ".pytest_cache",    # Python tests
                ".tox",             # Python
                "node_modules"      # NPM
            )

            foreach ($dir in $buildDirs) {
                $dirPath = Join-Path $Path $dir
                if (Test-Path $dirPath) {
                    if ($Quiet) {
                        $null = Remove-Item -Path $dirPath -Recurse -Force -ErrorAction SilentlyContinue
                        continue
                    }
                    Write-Host "  Removing: $dirPath" -ForegroundColor Gray
                    $null = Remove-Item -Path $dirPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            $results.Status = "success"
            $results.Command = "clean"
            $results.Duration = (Get-Date).Subtract($startTime).TotalSeconds
            if ($Quiet) {
                return $results
            }
            Write-Host "�... Build artifacts cleaned." -ForegroundColor Green
            return $results
        }

        # Modo lint
        if ($Mode -eq "lint") {
            if ($Quiet) {
                $results.Status = "partial"
                $results.Command = "lint"
                $results.OutputPath = Join-Path $Path ".lint_report"
                return $results
            }
            Write-Host "�"� Running linting checks..." -ForegroundColor Cyan

            switch ($language) {
                "JavaScript" {
                    if (Test-Path (Join-Path $Path "package.json")) {
                        try {
                            $null = Invoke-Expression "npm run lint 2>&1" 2>&1
                            $exitCode = $LASTEXITCODE
                            if ($exitCode -eq 0) {
                                $results.Status = "success"
                            } else {
                                $results.Status = "partial"
                            }
                        } catch {
                            $results.Status = "partial"
                        }
                    }
                }
                "Python" {
                    if (Test-Path (Join-Path $Path "setup.py")) {
                        try {
                            $null = Invoke-Expression "python -m py_compile ." 2>&1
                            $exitCode = $LASTEXITCODE
                            if ($exitCode -eq 0) {
                                $results.Status = "success"
                            } else {
                                $results.Status = "partial"
                            }
                        } catch {
                            $results.Status = "partial"
                        }
                    }
                }
                "Rust" {
                    try {
                        $null = Invoke-Expression "cargo check 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                        if ($exitCode -eq 0) {
                            $results.Status = "success"
                        } else {
                            $results.Status = "partial"
                        }
                    } catch {
                        $results.Status = "partial"
                    }
                }
                "Go" {
                    try {
                        $null = Invoke-Expression "go vet ./... 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                        if ($exitCode -eq 0) {
                            $results.Status = "success"
                        } else {
                            $results.Status = "partial"
                        }
                    } catch {
                        $results.Status = "partial"
                    }
                }
                "Java" {
                    try {
                        $null = Invoke-Expression "mvn checkstyle:check 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                        if ($exitCode -eq 0) {
                            $results.Status = "success"
                        } else {
                            $results.Status = "partial"
                        }
                    } catch {
                        $results.Status = "partial"
                    }
                }
                "C" | "C++" {
                    try {
                        $null = Invoke-Expression "clang-format --diff . 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                        if ($exitCode -eq 0) {
                            $results.Status = "success"
                        } else {
                            $results.Status = "partial"
                        }
                    } catch {
                        $results.Status = "partial"
                    }
                }
            }

            $results.Command = "lint"
            $results.Duration = (Get-Date).Subtract($startTime).TotalSeconds
            if ($Quiet) {
                return $results
            }
            Write-Host "�... Linting complete. Status: $($results.Status)" -ForegroundColor Gray
            return $results
        }

        # Modo test
        if ($Mode -eq "test") {
            if ($Quiet) {
                $results.Status = "partial"
                $results.Command = "test"
                $results.OutputPath = Join-Path $Path ".test_results"
                return $results
            }
            Write-Host "🧪 Running tests..." -ForegroundColor Cyan

            switch ($language) {
                "Rust" {
                    try {
                        $null = Invoke-Expression "cargo test --no-fail-fast 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                    } catch { $exitCode = $LASTEXITCODE }
                }
                "Python" {
                    try {
                        $null = Invoke-Expression "python -m unittest discover -s . 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                    } catch { $exitCode = $LASTEXITCODE }
                }
                "JavaScript" {
                    try {
                        $null = Invoke-Expression "npm run test 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                    } catch { $exitCode = $LASTEXITCODE }
                }
                "Go" {
                    try {
                        $null = Invoke-Expression "go test ./... -v 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                    } catch { $exitCode = $LASTEXITCODE }
                }
                "Java" {
                    try {
                        $null = Invoke-Expression "mvn test 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                    } catch { $exitCode = $LASTEXITCODE }
                }
                "Ruby" {
                    try {
                        $null = Invoke-Expression "bundle exec rake test 2>&1" 2>&1
                        $exitCode = $LASTEXITCODE
                    } catch { $exitCode = $LASTEXITCODE }
                }
            }

            if ($exitCode -eq 0) {
                $results.Status = "success"
            } else {
                $results.Status = "partial"
            }

            $results.Command = "test"
            $results.Duration = (Get-Date).Subtract($startTime).TotalSeconds
            if ($Quiet) {
                return $results
            }
            Write-Host "�... Tests complete. Status: $($results.Status)" -ForegroundColor Gray
            return $results
        }

        # Modo bundle
        if ($Mode -eq "bundle") {
            if (-not $Quiet) {
                Write-Host "�"� Creating bundled executable..." -ForegroundColor Cyan
            }

            $compiler = Get-Compiler -Language $language -OutputFile $Output

            # Verificar se bundler está disponível
            $bundleAvailable = $false
            switch ($language) {
                "Rust" {
                    $bundleAvailable = Check-Compiler-Available -Compiler "cargo-bundle"
                    if ($bundleAvailable) {
                        try {
                            $null = Invoke-Expression "cargo binstall cargo-bundle --force 2>&1" 2>&1
                        } catch {}
                        $bundleAvailable = Check-Compiler-Available -Compiler "cargo-bundle"
                    }
                }
                "Python" {
                    $bundleAvailable = Check-Compiler-Available -Compiler "pyinstaller"
                }
                "JavaScript" {
                    $bundleAvailable = Check-Compiler-Available -Compiler "webpack-cli"
                }
            }

            if ($bundleAvailable) {
                if ($Quiet) {
                    $results.Status = "success"
                    $results.Command = "bundle"
                    return $results
                }
                Write-Host "�... Bundler available: $(if ($bundleAvailable) { 'yes' } else { 'no' })" -ForegroundColor Gray
            } else {
                if ($Quiet) {
                    $results.Errors = "Bundler not available for $language"
                    return $results
                }
                Write-Host "⚠️ Warning: Bundler not available, falling back to compilation" -ForegroundColor Yellow
            }

            $results.Command = "bundle"
            $results.Status = "partial"
            $results.Duration = (Get-Date).Subtract($startTime).TotalSeconds
            if ($Quiet) {
                return $results
            }
            Write-Host "�... Bundle mode attempted (fallback to compile if bundler unavailable)" -ForegroundColor Gray
            return $results
        }

        # Modo compile padrão
        Write-Host "�"� Compiling project ($language)..." -ForegroundColor Cyan

        $compiler = Get-Compiler -Language $language -OutputFile $Output

        # Verificar se compilador está disponível
        $compilerAvailable = $false
        $compilerPath = Find-Compiler -Compiler $compiler.Command

        if ($compilerPath) {
            $compilerAvailable = $true
        }

        if (-not $compilerAvailable) {
            if ($Quiet) {
                $results.Errors = "Compiler not found: $($compiler.Command)"
                return $results
            }
            Write-Host "❌ Error: Compiler not found: $($compiler.Command)" -ForegroundColor Red
            Write-Host "       Please install $($compiler.Command) to compile $language projects." -ForegroundColor Yellow
            $results.Errors = "Compiler not found: $($compiler.Command). Please install $($compiler.Command) to compile $language projects."
            return $results
        }

        if ($Quiet) {
            $results.Status = "success"
            $results.Command = "$(if ($compiler.Command -eq "cargo") { "cargo build" } elseif ($compiler.Command -eq "npm") { "npm run build" } elseif ($compiler.Command -eq "pip" -and $language -eq "Python" ) { "pip install -e . " } elseif ($compiler.Command -eq "gcc") { "gcc -o output.exe source.c" } elseif ($compiler.Command -eq "dotnet") { "dotnet build" } elseif ($compiler.Command -eq "go") { "go build" } elseif ($compiler.Command -eq "python") { "python setup.py build" } elseif ($compiler.Command -eq "mvn") { "mvn package" } elseif ($compiler.Command -eq "bundle") { "bundle exec rake" } else { $compiler.Command })"
            return $results
        }

        # Executar compilação
        $commandBase = $compiler.Command

        # Construir comando base
        switch ($language) {
            "Rust" {
                $cmd = "cargo build"
                if ($Output) {
                    $cmd = "cargo build --release -o $Output"
                }
            }
            "Python" {
                $cmd = "pip install -e ."
                if ($config -and $config.Scripts) {
                    if ($config.Scripts.build) {
                        $cmd = "npm run build"
                    } elseif ($config.Scripts.install -match "python") {
                        $cmd = "pip install -e ."
                    }
                }
            }
            "JavaScript" {
                if ($config -and $config.Scripts) {
                    if ($config.Scripts.build) {
                        $cmd = "npm run build"
                    } elseif ($config.Scripts.dev) {
                        $cmd = "npm run dev"
                    } else {
                        $cmd = "npm run build"
                    }
                } else {
                    $cmd = "npm run build"
                }
            }
            "TypeScript" {
                if ($config -and $config.Scripts) {
                    if ($config.Scripts.build) {
                        $cmd = "npm run build"
                    } elseif ($config.Scripts.dev) {
                        $cmd = "npm run dev"
                    } else {
                        $cmd = "npm run build"
                    }
                } else {
                    $cmd = "npm run build"
                }
            }
            "C" {
                if ($configFile -eq "CMakeLists.txt") {
                    $cmd = "cmake --build build --config Release"
                } elseif ($configFile -eq "Makefile") {
                    $cmd = "make"
                } else {
                    $cmd = "gcc -o $Output $SourceFile"
                }
            }
            "C++" {
                if ($configFile -eq "CMakeLists.txt") {
                    $cmd = "cmake --build build --config Release"
                } elseif ($configFile -eq "Makefile") {
                    $cmd = "make"
                } else {
                    $cmd = "g++ -o $Output $SourceFile"
                }
            }
            "Go" {
                $cmd = "go build -o $Output ."
            }
            "Java" {
                $cmd = "mvn package"
            }
            "VB.NET" {
                $cmd = "dotnet build"
                if ($Output) {
                    $cmd += " -o $Output"
                }
            }
            "C#" {
                $cmd = "dotnet build"
                if ($Output) {
                    $cmd += " -o $Output"
                }
            }
            "F#" {
                $cmd = "dotnet build"
                if ($Output) {
                    $cmd += " -o $Output"
                }
            }
            "Ruby" {
                $cmd = "bundle exec rake"
            }
            default {
                $cmd = "build"
            }
        }

        $results.Command = $cmd
        Write-Host "Command: $cmd" -ForegroundColor Gray

        if ($Verbose) {
            Write-Host "Executing: $cmd" -ForegroundColor Cyan
        }

        try {
            if ($Quiet) {
                $null = Invoke-Expression $cmd
            } else {
                Invoke-Expression $cmd
            }
        } catch {
            if ($Quiet) {
                $results.Errors = $_.Exception.Message
                return $results
            }
            Write-Host "❌ Compilation error: $_" -ForegroundColor Red
        }

        # Verificar resultado
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            $results.Status = "success"
        } elseif ($exitCode -eq 1) {
            $results.Status = "partial"
        } else {
            $results.Status = "fail"
        }

        $results.Duration = (Get-Date).Subtract($startTime).TotalSeconds
        $results.OutputPath = if ($Output) { $Output } else { "build/$($language).exe" }
        if ($Quiet) {
            return $results
        }

        Write-Host "�... Build complete! Duration: $($results.Duration) seconds" -ForegroundColor Green
        Write-Host "Output: $($results.OutputPath)" -ForegroundColor Gray
        return $results
    }

    end {
        if ($Verbose -and $results.Status -ne "fail") {
            Write-Host "`n=== Build Summary ===" -ForegroundColor Cyan
            Write-Host "Status: $($results.Status)" -ForegroundColor $(if ($results.Status -eq "success") { "Green" } elseif ($results.Status -eq "partial") { "Yellow" } else { "Red" })
            Write-Host "Duration: $($results.Duration) seconds" -ForegroundColor Gray
            Write-Host "Command: $($results.Command)" -ForegroundColor Gray
        }
    }
}

# Export all functions
Export-ModuleMember -Function Build-Project, Detect-Language, Get-Compiler, Check-Compiler-Available, Find-Compiler, Parse-Project-Config, Format-Build-Result

