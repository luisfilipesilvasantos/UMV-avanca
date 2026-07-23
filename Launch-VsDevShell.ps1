<#
.SYNOPSIS Launch Developer PowerShell
.DESCRIPTION
Locates and imports a Developer PowerShell module and calls the Enter-VsDevShell cmdlet. The Developer PowerShell module
is located in one of several ways:
  1) From a path in a Visual Studio installation
  2) From the latest installation of Visual Studio (higher versions first)
  3) From the instance ID of a Visual Studio installation
  4) By selecting a Visual Studio installation from a list

By default, with no parameters, the path to this script is used to locate the Developer PowerShell module. If that fails,
then the latest Visual Studio installation is used. If both methods fail, then the user can select a Visual Studio installation
from a list.
.PARAMETER VsInstallationPath 
A path in a Visual Studio installation. The path is used to locate the Developer PowerShell module.
By default, this is the path to this script.
.PARAMETER Latest
Use the latest Visual Studio installation to locate the Developer PowerShell module.
.PARAMETER List
Display a list of Visual Studio installations to choose from. The choosen installation is used to locate the Developer PowerShell module.
.PARAMETER VsInstanceId
A Visual Studio installation instance ID. The matching installation is used to locate the Developer PowerShell module.
.PARAMETER ExcludePrerelease
Excludes Prerelease versions of Visual Studio from consideration. Applies only to Latest and List.
.PARAMETER VsWherePath
Path to the vswhere utility used to located and identify Visual Studio installations.
By default, the path is the well-known location shared by Visual Studio installations.
#>
[CmdletBinding(DefaultParameterSetName = "Default")]
param (
    [ValidateScript({Test-Path $_})]
    [Parameter(ParameterSetName = "VsInstallationPath")]
    [string]
    $VsInstallationPath = "$($MyInvocation.MyCommand.Definition)",

    [Parameter(ParameterSetName = "Latest")]
    [switch]
    $Latest,

    [Parameter(ParameterSetName = "List")]
    [switch]
    $List,

    [Parameter(ParameterSetName = "List")]
    [object[]]
    $DisplayProperties = @("displayName", "instanceId", "installationVersion", "isPrerelease", "installationName", "installDate"),

    [Parameter(ParameterSetName = "VsInstanceId", Mandatory = $true)]
    [string]
    $VsInstanceId,

    [Parameter(ParameterSetName = "Latest")]
    [Parameter(ParameterSetName = "List")]
    [switch]
    $ExcludePrerelease,

    [Parameter(ParameterSetName = "Default")]
    [Parameter(ParameterSetName = "VsInstallationPath")]
    [Parameter(ParameterSetName = "Latest")]
    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "VsInstanceId")]
    [ValidateSet('x86','amd64','x64','arm','arm64')]
    [string]
    $Arch,

    [Parameter(ParameterSetName = "Default")]
    [Parameter(ParameterSetName = "VsInstallationPath")]
    [Parameter(ParameterSetName = "Latest")]
    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "VsInstanceId")]
    [ValidateSet('x86','amd64','x64','arm64')]
    [string]
    $HostArch,

    [Parameter(ParameterSetName = "Default")]
    [Parameter(ParameterSetName = "VsInstallationPath")]
    [Parameter(ParameterSetName = "Latest")]
    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "VsInstanceId")]
    [switch]
    $SkipAutomaticLocation,

    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [Parameter(ParameterSetName = "Default")]
    [Parameter(ParameterSetName = "VsInstallationPath")]
    [Parameter(ParameterSetName = "Latest")]
    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "VsInstanceId")]
    [string]
    $VsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
)

function GetSetupConfigurations {
    param (
        $whereArgs
    )
    
    $expression = "& `"$VsWherePath`" $whereArgs -format json"
    Invoke-Expression $expression | ConvertFrom-Json
}

function LaunchDevShell {
    param (
        $config
    )

    $basePath = $config.installationPath
    $instanceId = $config.instanceId

    $currModulePath = "$basePath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    # Prior to 16.3 the DevShell module was in a different location
    $prevModulePath = "$basePath\Common7\Tools\vsdevshell\Microsoft.VisualStudio.DevShell.dll"

    $modulePath = if (Test-Path $prevModulePath) { $prevModulePath } else { $currModulePath }

    if (Test-Path $modulePath) {
        Write-Verbose "Found at $modulePath."

        try {
            Import-Module $modulePath
        }
        catch [System.IO.FileLoadException] {
            Write-Verbose "The module has already been imported from a different installation of Visual Studio:"
            (Get-Module Microsoft.VisualStudio.DevShell).Path | Write-Verbose
        }

        $params = @{
            VsInstanceId = $instanceId
        }

        $command = Get-Command Enter-VsDevShell

        if ($SkipAutomaticLocation)
        {
            $params.SkipAutomaticLocation = $true
        }

        # -Arch is only available from 17.1
        if ($Arch -and $command.Parameters.ContainsKey("Arch"))
        {
            $params.Arch = $Arch
        }

        # -HostArch is only available from 17.1
        if ($HostArch -and $command.Parameters.ContainsKey("HostArch"))
        {
            $params.HostArch = $HostArch
        }

        # -ReportNewInstanceType is only available from 16.5
        if ($command.Parameters.ContainsKey("ReportNewInstanceType")) {
            $params.ReportNewInstanceType = "LaunchScript"
        }

        $boundParams = $PSCmdlet.MyInvocation.BoundParameters

        if ($boundParams.ContainsKey("Verbose") -and
            $boundParams["Verbose"].IsPresent)
        {
            Write-Verbose "Enter-VsDevShell Parameters:"
            $params.GetEnumerator() | ForEach-Object{
                $message = '{0} = {1}' -f $_.key, $_.value
                Write-Verbose $message
            }
        }

        Enter-VsDevShell @params
        exit
    }

    throw [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Required assembly could not be located. This most likely indicates an installation error. Try repairing your Visual Studio installation. Expected location: $modulePath"),
        "DevShellModuleLoad",
        [System.Management.Automation.ErrorCategory]::NotInstalled,
        $config)
}

function VsInstallationPath {
    $setupargs = "-path `"$VsInstallationPath`""

    Write-Verbose "Using path: $VsInstallationPath"
    $config = GetSetupConfigurations($setupargs)
    LaunchDevShell($config)
}

function Latest {
    $setupargs = "-latest"

    if (-not $ExcludePrerelease) {
        $setupargs += " -prerelease"
    }

    $config = GetSetupConfigurations($setupargs)
    LaunchDevShell($config)
}

function VsInstanceId {
    $configs = GetSetupConfigurations("-prerelease -all")
    $config = $configs | Where-Object { $_.instanceId -eq $VsInstanceId }
    if ($config) {
        Write-Verbose "Found Visual Studio installation with InstanceId of '$($config.instanceId)' and InstallationPath '$($config.installationPath)'"
        LaunchDevShell($config)
        exit
    }

    throw [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Could not find an installation of Visual Studio with InstanceId '$VsInstanceId'."),
        "VsSetupInstance",
        [System.Management.Automation.ErrorCategory]::InvalidArgument,
        $config)
}

function List {
    $setupargs = "-sort"

    if (-not $ExcludePrerelease) {
        $setupargs = " -prerelease"
    }

    $configs = GetSetupConfigurations($setupargs)

    $DisplayProperties = @("#") + $DisplayProperties

    # Add an incrementing select column
    $configs = $configs |
        Sort-Object displayName, installationDate |
        ForEach-Object {$i = 0}{ $i++; $_ | Add-Member -NotePropertyName "#" -NotePropertyValue $i -PassThru }

    Write-Host "The following Visual Studio installations were found:"
    $configs | Format-Table -Property $DisplayProperties

    $selected = Read-Host "Enter '#' of the Visual Studio installation to launch DevShell. <Enter> to quit: "
    if (-not $selected) { exit }

    $config = $configs | Where-Object { $_."#" -eq $selected }

    if ($config) {
        LaunchDevShell($config)
    }
    else {
        "Invalid selection: $selected"
    }
}

function Default{
    Write-Verbose "No parameters passed to script. Trying VsInstallationPath."

    try {
        VsInstallationPath
        exit
    }
    catch {
        Write-Verbose "VsInstallationPath failed. Trying Latest."
    }

    Write-Host "Could not start Developer PowerShell using the script path."
    Write-Host "Attempting to launch from the latest Visual Studio installation."

    try {
        Latest
        exit
    }
    catch {
        Write-Verbose "Latest failed. Defaulting to List."
    }

    Write-Host "Could not start Developer PowerShell from the latest Visual Studio installation."
    Write-Host

    List
}

if ($PSCmdlet.ParameterSetName) {
    & (Get-ChildItem "Function:$($PSCmdlet.ParameterSetName)")
    exit
}
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDGPwt47mSxoN03
# zQxp07r0lU/VE1OvRN62atO2nDOjraCCDXYwggX0MIID3KADAgECAhMzAAAEhV6Z
# 7A5ZL83XAAAAAASFMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM3WhcNMjYwNjE3MTgyMTM3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDASkh1cpvuUqfbqxele7LCSHEamVNBfFE4uY1FkGsAdUF/vnjpE1dnAD9vMOqy
# 5ZO49ILhP4jiP/P2Pn9ao+5TDtKmcQ+pZdzbG7t43yRXJC3nXvTGQroodPi9USQi
# 9rI+0gwuXRKBII7L+k3kMkKLmFrsWUjzgXVCLYa6ZH7BCALAcJWZTwWPoiT4HpqQ
# hJcYLB7pfetAVCeBEVZD8itKQ6QA5/LQR+9X6dlSj4Vxta4JnpxvgSrkjXCz+tlJ
# 67ABZ551lw23RWU1uyfgCfEFhBfiyPR2WSjskPl9ap6qrf8fNQ1sGYun2p4JdXxe
# UAKf1hVa/3TQXjvPTiRXCnJPAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUuCZyGiCuLYE0aU7j5TFqY05kko0w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwNTM1OTAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBACjmqAp2Ci4sTHZci+qk
# tEAKsFk5HNVGKyWR2rFGXsd7cggZ04H5U4SV0fAL6fOE9dLvt4I7HBHLhpGdE5Uj
# Ly4NxLTG2bDAkeAVmxmd2uKWVGKym1aarDxXfv3GCN4mRX+Pn4c+py3S/6Kkt5eS
# DAIIsrzKw3Kh2SW1hCwXX/k1v4b+NH1Fjl+i/xPJspXCFuZB4aC5FLT5fgbRKqns
# WeAdn8DsrYQhT3QXLt6Nv3/dMzv7G/Cdpbdcoul8FYl+t3dmXM+SIClC3l2ae0wO
# lNrQ42yQEycuPU5OoqLT85jsZ7+4CaScfFINlO7l7Y7r/xauqHbSPQ1r3oIC+e71
# 5s2G3ClZa3y99aYx2lnXYe1srcrIx8NAXTViiypXVn9ZGmEkfNcfDiqGQwkml5z9
# nm3pWiBZ69adaBBbAFEjyJG4y0a76bel/4sDCVvaZzLM3TFbxVO9BQrjZRtbJZbk
# C3XArpLqZSfx53SuYdddxPX8pvcqFuEu8wcUeD05t9xNbJ4TtdAECJlEi0vvBxlm
# M5tzFXy2qZeqPMXHSQYqPgZ9jvScZ6NwznFD0+33kbzyhOSz/WuGbAu4cHZG8gKn
# lQVT4uA2Diex9DMs2WHiokNknYlLoUeWXW1QrJLpqO82TLyKTbBM/oZHAdIc0kzo
# STro9b3+vjn2809D0+SOOCVZMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAASFXpnsDlkvzdcAAAAABIUwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAEei+KUpNLT2nossya7W2VC
# iQyH1lt/miVpMVUooILtMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAhDjJASZJb26Dl8Qwo/k3Tx6jxzyk3AfrpoIFNws0/c4YnYz22/c8ThkA
# ddU0YrbcLZt+2EDMACayBuY4Gq9fEqAcNiVW5jw0ZvImCDsXKyi3+t5b2oEiVhHy
# 1KTnOezhoCvf2G+9Ynpl8MHLBbjB+v93xdhjdQCzZMpWwBlSrBEHc5KvbVcb8fW7
# SqWQa5LiHwqMvOan97Bk9zi76Jp5cF7WcgSp46lTNgyPXOGPf7C3P0MTHiz3W1ZR
# PJVrYmJ4IzzUJw6W8AUU5CSjl8NaMsqbpBPtCyQqfFDKpl9JScVXMNrofT1dxgfL
# cJo+dQ7TWMwR0v+3HRJTBRu+adVoG6GCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBZbZJpi85AIDOR44bNq/xiDtZhyOlQb/qR9l6ViN7OIQIGabhv7WJa
# GBMyMDI2MDQwOTIwNTIyMi44MjVaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzMwMy0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAiEzwDX70g8hpAABAAACITANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTM5
# NTRaFw0yNzA1MTcxOTM5NTRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzMwMy0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDbcTACqU1YvRocyWL2PL9fyf/+ULs2qK7U1aZsRnDZ
# SnlCr7K7jgA3eFCEJL5BZ7dUTC0DeZepf+ZC+7HEbB4IdzmJfQAUDFFerqY5VTHm
# QvP2XA3lWSFj740idcGUHglP5H/PbCJU7GAHWP2HdcCjdx1lYAo0A+zLI7xwnTQe
# MyOXX212Eg4UmDPPJgxdTMw6WFVWsBPWRBi5gDixy2s+7R8ADk5lbBBFDB5h0Cjr
# NWIN7uCAzF5g7trrL8nXIKp10mj9RxhcGQ+tlht6VIvdygRVTUGdzFB2/nBvJqQ9
# kxxFltQST70fEdx4TyaKow/f5+BSh4z4/9f7NXIVVTLn/8kcJAfRqFmRrrFt3IKb
# y7VrzmYuoQWD0lmNFtGQ57BrJkPrPFAPek1ALtcbb7FH3nQpvi8ngz/MFX/+cnmN
# FWFU29VVLmzB9XvLZxbYvkeett0mh5lfteeN2rEwUyrdrKufz9h2S6pbate+C2h0
# 2CrXwSka0x6ezpTmGkIJLFt25ub/UYXNLdHdsxGD6EfckOIoJYsm4MS9F/vSqLNH
# K89I0vTLBngQEp6LIFkINanRT3PtNx3pNKRKJRALc6L6mhW4hL4aHL749qPfQ72t
# 5qAMm5xiKYMgJ2WanidRLNuI251JIN7raaeA/2vb0XFkZcIbTR1pfQGsco4U0g5t
# jwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFOYjIs5qa6pfuquPyyK1FTr5QDCnMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQA4I/3bkdnTxD2rFum3MF8xVKdEkohAObbe
# PrQ+0fr5bRimjz9sVkKT/7gcj4OMcClSYG+IdX6Mp3EYsLHWfjvwfzFoeZE+yTbd
# Bj/1VHZQRuCmw6QqeVCTbw2nnS7nBxnWd9oZXbPUpqEawH5DqXQaWFgR9A4KWVK/
# IvXVDMj1PlPCES1P3JonNbdhkkkz49rJuKOm5b7e/BH8loqAmXOXRc22yxWVTMWr
# Ep4pslmv8eT7VoY8X/jdKYTPVEXsfmLbVFcqzMuB8vFGfUyWsWROS8wgq7lQYfWc
# Yqh7NymoATX+wWYK3zWG7aRciPGUAzznXdf+aHtIWnQLNa5HFmSXkiak3fSuprWY
# ZiHhuYjE16hroApcBHpm+8S/kNqhm9WjQX+2BxnYv+Jejy6lqTi8fLBLS069WXVw
# /ptf5IV+FtYl34GvVoeg31UoUmVVZe1SDUJkm9dDXc8l/qBDYiAIT2CCsPTyt9XA
# 9JVuHxdP63n7ChvWAO/47QRuCDsUlFJoWwyBwl7jeYpaRVMtQt0iuJMGGjgEaJX1
# Q/2j8sXURvTceLHDD9ipWt092ZDWMQciDRmhHNFOX1dnjBvk/k1UMcg997j5oYzn
# AnSpJvlg/4BP3aVE0h/YH2KgsKbU4NXZHAjJXj2Slqo1C115CG6qBZaFkM8W6vPZ
# Cm5qnSezOjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjMzMDMtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQAL
# bEgZZnyYHXJ1DGb5fGjplXptuaCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7YKO7zAiGA8yMDI2MDQwOTIwNDc0
# M1oYDzIwMjYwNDEwMjA0NzQzWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDtgo7v
# AgEAMAcCAQACAhZBMAcCAQACAhIcMAoCBQDtg+BvAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAMXpoKTT0T/SWCGW1Xc7+Gzp8EIzMj4JQhAkeE3L9dUk2+uY
# c4C80I/T/Iol0uf17SMnXLRZR600VSMjvcDE+5Kv5ZEWYeNieim4SKxB+sKtQ3Nn
# S2pGQ3nmjg8vj81/8wALa1UaXn8YIhq9KrkC8w3HUhsiIDS2YpA0qJRvwbjhrsz5
# SmoJEPp3PIBNpQe6TQcrKNFB4HEQSdqyjh+IxhSIfFmahxnon9DapyEqdXQ8iO0J
# RD+OzDGjKDQcPBiwjRit67SfNqPAIrvhEuo3vvfPOcQtmtxouoWEE4/s15D+CTlA
# puhbo7Ak7yynqWFUHcF9keO9Tbdh4f5frzquh38xggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiEzwDX70g8hpAABAAACITAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCCRAoVj69MbhrJwu+ie0ciWWZvzQviqD7PrZBALLAzMBjCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIADvIQefFVUa4BJy8IZywMAvmGSK
# dUVqEmy9A++PCj1EMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAIhM8A1+9IPIaQAAQAAAiEwIgQgfDuFY9vu/2IF1gytE+gN5gFKNnjv
# 4CV47+nJ+zRFWr4wDQYJKoZIhvcNAQELBQAEggIALk0iCQYbNVyWVF5/heHcjhiV
# +7MW9A0zEk6x2fOG8nGlK7/moNiwBPRgqRZ4xkl2mDvXBOZQQZfAnARuB2RkB7vb
# xgkKc1++LkDxykVRJm/Lt9imufPOJ75wGTsWq8XPFi7mm/94zW00vqMSXbpbkke2
# NbHANoQAgebcl2KW3pb9AG9d18Myehf606Y2py4GI7igTW7P0C4eQuD2bEb9n/1b
# on6YJOsJdNX0GsqdHyHn2yjSRuRZP8bC4KHXwTutfiI77aMVs57Fi7tJAPQE9pOR
# w8v4IxLEhl/kBbY46hPcXQZXlaNlKAZDiR+2cryNOd+cjA114WFRH/Que5U/xQWr
# lm8g/o9khweZMN+BL4FRB6/iNFmL49r5GfvjX5/DxF1pbgKkS6vgeTD8X3R6qy51
# fcONYQY4vownbD9E3rHkgmWdZ6ShT6Q3DnmCBanaOA5OYwG9ifEXXckGEyEg/0/J
# ePU/X3YPFni64Zhc+5dJ6XmYgmds8zCff5486NEMdFYDMUtv9D42a3tB2h2ZsITp
# 3NGatiNrOowypBeIl91n5E9F4mjQlTn+JW2uL2v2Mbke0+AorHc/eJi6O9ynwzcm
# EIdOwS7bqZvpt2Aq7qjgRU9kGd6vQbkMzApR8MoHBqdv3SoB5eWxqXIBlKveJto1
# isC91oM+qyaf/zi0FF4=
# SIG # End signature block

