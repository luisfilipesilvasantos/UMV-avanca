$filePath = "VirtualGpuMemory.cpp"
$code = Get-Content $filePath -Raw

# 1. Injetar as funções assíncronas no final do ficheiro se não existirem
$asyncFunctions = @'

bool VirtualGpuMemory::writeBlockAsync(size_t blockId, const void* data, size_t size, cudaStream_t stream) {
    BlockLocation loc;
    if (!getBlockLocation(blockId, loc)) return false;
    if (loc.tier != MemoryTier::Vram) return false;
    cudaError_t err = cudaSetDevice(loc.deviceId);
    if (err != cudaSuccess) return false;
    err = cudaMemcpyAsync(reinterpret_cast<void*>(loc.physicalOffset), data, size, cudaMemcpyHostToDevice, stream);
    return (err == cudaSuccess);
}

void VirtualGpuMemory::synchronizeStream(int deviceId, cudaStream_t stream) {
    cudaSetDevice(deviceId);
    cudaStreamSynchronize(stream);
}
'@

if ($code -notcontains "writeBlockAsync") {
    $code += $asyncFunctions
    Write-Host "[PATCH] Funções assíncronas injetadas no final do ficheiro."
}

# 2. Substituir a lógica sequencial de allocateVram pelo Striping Circular (RAID 0)
$oldAllocLoop = "for (size_t i = 0; i < m_gpuDevices.size(); ++i) {"
$newAllocLoop = 'size_t targetGpu = blockId % m_gpuDevices.size();
    for (size_t idx = 0; idx < m_gpuDevices.size(); ++idx) {
        size_t i = (targetGpu + idx) % m_gpuDevices.size();'

if ($code.Contains($oldAllocLoop)) {
    $code = $code.Replace($oldAllocLoop, $newAllocLoop)
    Write-Host "[PATCH] Lógica de Loop Sequencial substituída por Stride Circular (RAID 0)."
}

# 3. Salvar o ficheiro modificado com encoding correto
Set-Content -Path $filePath -Value $code -Encoding UTF8
Write-Host "[PATCH] Ficheiro VirtualGpuMemory.cpp atualizado com sucesso!"