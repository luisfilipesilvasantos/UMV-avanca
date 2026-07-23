# fallback-check.ps1
$gpuInfo = & nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits
$freeVRAM = [int]$gpuInfo

if ($freeVRAM -lt 4000) {
    # Define variável de ambiente para fallback
    [System.Environment]::SetEnvironmentVariable("USE_CPU_FALLBACK", "1", "User")
}

