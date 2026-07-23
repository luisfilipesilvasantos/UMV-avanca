:: 1) Reparar imagem do Windows (WinSxS + CBS)
DISM /Online /Cleanup-Image /RestoreHealth

:: 2) Reparar ficheiros do sistema
sfc /scannow

:: 3) Reinstalar Windows Update + Microsoft Update
Set-Service wuauserv -StartupType Automatic
Set-Service bits -StartupType Automatic
Set-Service cryptsvc -StartupType Automatic
Set-Service trustedinstaller -StartupType Manual

net stop wuauserv
net stop bits
net stop cryptsvc
net stop trustedinstaller

rd /s /q %windir%\SoftwareDistribution
rd /s /q %windir%\System32\catroot2

net start wuauserv
net start bits
net start cryptsvc
net start trustedinstaller

:: 4) Reinstalar Microsoft Store e dependências (CORRIGIDO)
Get-AppxPackage -allusers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register \$($_.InstallLocation)\AppxManifest.xml\ }

:: 5) Reinstalar WebView2 (essencial para apps modernas)
winget install Microsoft.EdgeWebView2Runtime --silent --force

:: 6) Reinstalar .NET runtimes essenciais
winget install Microsoft.DotNet.Runtime.6 --silent --force
winget install Microsoft.DotNet.Runtime.7 --silent --force
winget install Microsoft.DotNet.Runtime.8 --silent --force

:: 7) Reinstalar PowerShell
winget install Microsoft.PowerShell --silent --force

:: 8) Reinstalar WSL (inclui fetch_events)
wsl --install
wsl --update

:: 9) Reinstalar drivers OEM via Windows Update (CORRIGIDO)
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot

:: 10) Reinstalar componentes opcionais essenciais
DISM /Online /Add-Capability /CapabilityName:WMIC~~~~
DISM /Online /Add-Capability /CapabilityName:Rsat.Tools~~~~
DISM /Online /Add-Capability /CapabilityName:OpenSSH.Client~~~~
DISM /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~


