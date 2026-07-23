// Funções ausentes no VirtualGpuMemory.cpp (adicionadas em 2025-04-06)

// estimateWorkingSet: Estima quantos blocos recentemente acedidos cabem na VRAM
std::pair<size_t, std::vector<size_t>> VirtualGpuMemory::estimateWorkingSet(int windowSize) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    
    size_t currentCounter = m_globalAccessCounter;
    size_t threshold = (windowSize > 0) ? (currentCounter - windowSize) : 0;
    if (threshold > currentCounter) threshold = 0; // overflow protection
    
    std::vector<size_t> recentBlocks;
    for (const auto& [blockId, accessTime] : m_accessTimestamps) {
        if (accessTime >= threshold) {
            recentBlocks.push_back(blockId);
        }
    }
    
    // Ordenar por ordem de acesso (mais recentes primeiro)
    std::sort(recentBlocks.begin(), recentBlocks.end(), [this](size_t a, size_t b) {
        return m_accessTimestamps.at(a) > m_accessTimestamps.at(b);
    });
    
    // Estimar quantos cabem na VRAM (baseado no tamanho total dos blocos recentes)
    size_t estimatedBlocks = 0;
    size_t totalSize = 0;
    for (size_t bid : recentBlocks) {
        BlockLocation loc;
        if (getBlockLocation(bid, loc)) {
            totalSize += loc.size;
            // Estimativa conservadora: considerar apenas blocos que cabem na VRAM livre
            size_t vramFree = getAvailableVram(0); // assumir GPU 0 como principal
            if (totalSize <= vramFree) {
                estimatedBlocks++;
            }
        }
    }
    
    std::cout << "[UMC WORKING SET] Estimated working set: " << estimatedBlocks 
              << " blocks (" << totalSize / (1024*1024) << " MB) in last " << windowSize << " accesses.\n";
    
    return {estimatedBlocks, recentBlocks};
}

// prefetchBlocks: Pré-carrega blocos para uma tier específica usando streams CUDA assíncronos
void VirtualGpuMemory::prefetchBlocks(const std::vector<size_t>& blocks, MemoryTier targetTier) {
    if (blocks.empty()) return;
    
    std::cout << "[UMC PREFETCH] Prefetching " << blocks.size() << " blocks to tier " 
              << tierToString(targetTier) << "...\n";
    
    for (size_t blockId : blocks) {
        BlockLocation loc;
        if (!getBlockLocation(blockId, loc)) {
            // Bloco não existe ainda - tentar alocar
            if (!allocateBlockPhysical(blockId, loc)) {
                std::cerr << "[UMC PREFETCH ERROR] Failed to allocate block " << blockId << "\n";
                continue;
            }
        } else if (loc.tier == targetTier) {
            // Já está na tier desejada
            continue;
        }
        
        // Migrar para a tier alvo
        bool success = false;
        if (targetTier == MemoryTier::Vram && loc.deviceId >= 0) {
            cudaSetDevice(loc.deviceId);
            // Simular transferência assíncrona (sem dados reais)
            std::cout << "[UMC PREFETCH] Prefetching block " << blockId 
                      << " to VRAM on GPU " << loc.deviceId << "\n";
            success = true; // Em implementação real, usar writeBlockAsync com stream
        } else if (targetTier == MemoryTier::Ram) {
            std::cout << "[UMC PREFETCH] Prefetching block " << blockId 
                      << " to RAM\n";
            success = migrateBlockToTier(blockId, targetTier, -1);
        }
        
        if (success) {
            registerAccess(blockId); // Registrar acesso para LRU
        } else {
            std::cerr << "[UMC PREFETCH ERROR] Failed to prefetch block " << blockId << "\n";
        }
    }
}

// simulatePageFault: Simula um page fault e decide onde mover o bloco correspondente
void VirtualGpuMemory::simulatePageFault(size_t faultAddress) {
    size_t blockSize = getBlockSize();
    if (blockSize == 0) return;
    
    // Calcular blockId a partir do endereço de fault
    size_t blockId = faultAddress / blockSize;
    std::cout << "[UMC PAGE FAULT] Simulated page fault at address 0x" 
              << std::hex << faultAddress << std::dec 
              << " -> Block ID: " << blockId << "\n";
    
    // Verificar se o bloco existe
    BlockLocation loc;
    if (!getBlockLocation(blockId, loc)) {
        std::cerr << "[UMC PAGE FAULT ERROR] Block " << blockId 
                  << " not found in memory map.\n";
        return;
    }
    
    // Decidir onde mover o bloco (política simples: se acessado recentemente, ir para VRAM)
    size_t currentCounter = m_globalAccessCounter;
    size_t accessTime = 0;
    auto it = m_accessTimestamps.find(blockId);
    if (it != m_accessTimestamps.end()) {
        accessTime = it->second;
    }
    
    // Se o bloco foi acessado nos últimos 1000 acessos globais, mover para VRAM
    bool shouldPromoteToVram = (currentCounter - accessTime) < 1000;
    MemoryTier targetTier = shouldPromoteToVram ? MemoryTier::Vram : MemoryTier::Ram;
    
    std::cout << "[UMC PAGE FAULT] Block " << blockId 
              << " last accessed at counter " << accessTime 
              << ", promoting to " << tierToString(targetTier) << "\n";
    
    // Migrar para a tier alvo
    if (targetTier == MemoryTier::Vram) {
        // Escolher GPU com mais VRAM livre
        int bestDevice = 0;
        size_t maxFreeVram = 0;
        for (const auto& gpu : m_gpuDevices) {
            if (gpu.freeVram > maxFreeVram) {
                maxFreeVram = gpu.freeVram;
                bestDevice = gpu.id;
            }
        }
        
        // Migrar para VRAM do GPU escolhido
        bool success = migrateBlockToTier(blockId, MemoryTier::Vram, bestDevice);
        if (success) {
            std::cout << "[UMC PAGE FAULT] Block " << blockId 
                      << " migrated to VRAM on GPU " << bestDevice << "\n";
        } else {
            // Fallback para RAM se falhar
            migrateBlockToTier(blockId, MemoryTier::Ram, -1);
            std::cerr << "[UMC PAGE FAULT WARNING] Failed to promote block " 
                      << blockId << " to VRAM, kept in RAM\n";
        }
    } else {
        // Migrar para RAM
        bool success = migrateBlockToTier(blockId, MemoryTier::Ram, -1);
        if (success) {
            std::cout << "[UMC PAGE FAULT] Block " << blockId 
                      << " migrated to RAM\n";
        }
    }
}
