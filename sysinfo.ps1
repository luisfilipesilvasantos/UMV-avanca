<#
.SYNOPSIS
    sysinfo - Exibir informações gerais do sistema Windows.

.DESCRIPTION
    Mostra informações básicas do sistema operacional: nome, versão,
    arquitetura, uptime, hostname, usuário atual, memória total.

.PARAMETER Verbose
    Mostra detalhes adicionais sobre o sistema.

.EXAMPLE
    sysinfo
    sysinfo -verbose
#>

Function Global:SysInfo {
    [CmdletBinding()]
    Param(
        [switch]$Json
    )

    $osInfo = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    $info = @{
        Hostname      = $env:COMPUTERNAME
        Architecture  = $env:PROCESSOR_ARCHITECTURE
        Platform      = $env:OS
        Edition       = $osInfo.ProductName
        BuildNumber   = if ($osInfo.CurrentBuildNumber) { $osInfo.CurrentBuildNumber } else { 0 }
        CPUs          = (Get-CimInstance Win32_Processor).Count
        Ram           = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB, 0)
        BiosDate      = (Get-CimInstance Win32_Bios).ReleaseDate
    }

    if ($Json) {
        $info | ConvertTo-Json -Depth 10
    } else {
        $info | Format-List
    }
}

