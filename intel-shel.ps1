<#
intel-shel.ps1 - helper to start LTX training and tail logs
Usage examples:
  # start training in current window
  .\intel-shel.ps1 -Train

  # start training and tail the log in the same window
  .\intel-shel.ps1 -Train -Tail

  # start training in a new PowerShell window and tail log in another window
  .\intel-shel.ps1 -Train -Tail -NewWindow
#>

param(
    [switch]$Train,
    [switch]$Tail,
    [int]$TailLines = 200,
    [switch]$NewWindow,
    [switch]$UseIntelligentTerminal
)

$ScriptDir = "D:\ComfyUI_windows_portable_nvidia_cu126\ltx-training"

function Start-Training {
    Write-Host "Starting training in $ScriptDir" -ForegroundColor Green
    Set-Location $ScriptDir
    # call the existing training script
    .\run_training.ps1
}

function Tail-Log {
    Set-Location $ScriptDir
    $log = Join-Path $ScriptDir 'output\train.log'
    if (-Not (Test-Path $log)) {
        Write-Host "Log not found: $log" -ForegroundColor Yellow
        return
    }
    Write-Host "Tailing $log (last $TailLines lines)" -ForegroundColor Cyan
    Get-Content $log -Tail $TailLines -Wait
}

# If user requested Intelligent Terminal, try to open Windows Terminal with the "Microsoft.IntelligentTerminal" profile
if ($UseIntelligentTerminal) {
    $hasWt = (Get-Command wt.exe -ErrorAction SilentlyContinue) -ne $null
    $hasWtCli = (Get-Command wtcli -ErrorAction SilentlyContinue) -ne $null

    if (-not $hasWt -and -not $hasWtCli) {
        Write-Host "Neither wt.exe nor wtcli were found; falling back to Start-Process powershell." -ForegroundColor Yellow
    } else {
        # prepare commands
        if ($Train) { $cmd = "Set-Location '$ScriptDir'; .\\run_training.ps1" }
        if ($Tail)  { $cmd2 = "Set-Location '$ScriptDir'; Get-Content .\\output\\train.log -Tail $TailLines -Wait" }

        # If we're already inside a Windows Terminal pane we can use wtcli to talk to the host
        if ($env:WT_COM_CLSID -and $hasWtCli) {
            Write-Host "Using wtcli (inside Windows Terminal) to create Intelligent Terminal tabs..." -ForegroundColor Green
            if ($Train) {
                & wtcli new-tab --profile "Microsoft.IntelligentTerminal" powershell -NoExit -Command $cmd
            }
            if ($Tail) {
                & wtcli new-tab --profile "Microsoft.IntelligentTerminal" powershell -NoExit -Command $cmd2
            }
            return
        }

        # Otherwise fall back to wt.exe which can be invoked from outside
        $wtArgsList = @()
        if ($Train) { $wtArgsList += @('new-tab','-p','Microsoft.IntelligentTerminal','powershell','-NoExit','-Command',$cmd) }
        if ($Tail)  { $wtArgsList += @('new-tab','-p','Microsoft.IntelligentTerminal','powershell','-NoExit','-Command',$cmd2) }
        if ($wtArgsList.Count -gt 0) {
            Write-Host "Launching Windows Terminal (Intelligent Terminal) via wt.exe..." -ForegroundColor Green
            Start-Process wt.exe -ArgumentList $wtArgsList
            return
        }
    }
}

if ($NewWindow) {
    # start training in a new PS window (non-Intelligent Terminal fallback)
    if ($Train) {
        Start-Process powershell -ArgumentList "-NoProfile -NoExit -Command \"Set-Location '$ScriptDir'; .\\run_training.ps1\""
    }
    if ($Tail) {
        Start-Sleep -Seconds 2
        Start-Process powershell -ArgumentList "-NoProfile -NoExit -Command \"Set-Location '$ScriptDir'; Get-Content .\\output\\train.log -Tail $TailLines -Wait\""
    }
    return
}

# default behaviour: if no switches provided, start training
if (-Not ($PSBoundParameters.Count -gt 0)) {
    $Train = $true
}

if ($Train) { Start-Training }
if ($Tail) { Tail-Log }

