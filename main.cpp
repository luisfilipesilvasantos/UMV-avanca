#include "VirtualGpuMemory.h"
#include "UMCModelLoader.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <algorithm>
#include <thread>
#include <chrono>

// Forward declaration para tierToString (definida em VirtualGpuMemory.cpp)
std::string tierToString(MemoryTier tier);

// Prototypes
bool createDummyModelFile(const std::string& path, size_t sizeBytes);
bool verifyModelData(VirtualGpuMemory& virtualMem, size_t sizeBytes);
bool testByteGranularAccess(VirtualGpuMemory& virtualMem);

int main() {
    std::cout << "========================================================\n ";
    std::cout << "   Unified Memory Controller (UMC) - Windows & CUDA\n ";
    std::cout << "========================================================\n ";

    // 1. Create the VirtualGpuMemory space with 4 MB blocks
    const size_t blockSize = 4 * 1024 * 1024;
    // Enforce 16 MB limits per tier to demonstrate fallback (4 blocks VRAM, 4 blocks RAM, 4 blocks Pagefile)
    VirtualGpuMemory virtualMem(blockSize,
                                16 * 1024 * 1024,
                                16 * 1024 * 1024,
                                16 * 1024 * 1024);

    // Initialize hardware configuration (NVML, system RAM, pagefile stats)
    if (!virtualMem.initialize()) {
        std::cerr << "[FATAL] Failed to initialize VirtualGpuMemory. Exiting.\n ";
        return -1;
    }

    // 2. Generate a dummy model file.
    // 48 MB dummy file will distribute perfeitamente across the tiers.
    const size_t dummyModelSize = 48 * 1024 * 1024;
    const std::string modelPath = "dummy_model.bin";

    std::cout << "[DEMO INFO] Creating dummy model file on disk...\n ";
    if (!createDummyModelFile(modelPath, dummyModelSize)) {
        return -1;
    }

    // 3. Load model using UMCModelLoader
    UMCModelLoader loader(virtualMem);
    size_t blocksLoaded = 0;
    if (!loader.loadModel(modelPath, blocksLoaded)) {
        std::cerr << "[DEMO ERROR] Model loading failed.\n ";
        std::remove(modelPath.c_str());
        return -1;
    }

    // 4. Introspect where each block is stored
    virtualMem.dumpLayout();

    // 5. Query specific block mapping
    BlockLocation queryLoc;
    size_t queryBlockId = 0; // First block
    if (virtualMem.getBlockLocation(queryBlockId, queryLoc)) {
        std::cout << "[DEMO INFO] Introspected Block " << queryBlockId << ":\n "
                  << "   - Tier:            " << tierToString(queryLoc.tier) << "\n "
                  << "   - Device ID:       " << ((queryLoc.deviceId == -1) ? "Host" : std::to_string(queryLoc.deviceId)) << "\n "
                  << "   - Physical Offset: 0x" << std::hex << queryLoc.physicalOffset << std::dec << "\n "
                  << "   - Size:            " << queryLoc.size / (1024 * 1024) << " MB\n ";
    }

    // 6. Verify consistency and ensure no data corruption occurred
    if (!verifyModelData(virtualMem, dummyModelSize)) {
        std::cerr << "[DEMO ERROR] Verification failed: data corruption detected.\n ";
        std::remove(modelPath.c_str());
        return -1;
    }

    // 7. Test byte-granular logical read/write spanning across block boundaries
    if (!testByteGranularAccess(virtualMem)) {
        std::cerr << "[DEMO ERROR] Byte-granular boundary test failed.\n ";
        std::remove(modelPath.c_str());
        return -1;
    }

    // --- DEMONSTRAÇÃO DAS NOVAS FUNCIONALIDADES ---
    std::cout << "\n [DEMO INFO] Testing NEW UMC Features... ";

    // Teste de Working Set Estimation
    std::cout << "\n [DEMO TEST] Estimating Working Set... ";
    auto [ws_size, ws_blocks] = virtualMem.estimateWorkingSet(200); // Janela de 200 acessos
    std::cout << "[DEMO RESULT] Working Set estimated: "
              << ws_size / (1024 * 1024) << " MB, "
              << ws_blocks.size() << " blocks.\n ";

    // Teste de Thrashing Detection (simulado)
    std::cout << "\n [DEMO TEST] Simulating Thrashing Detection... ";
    // Simula muitas migrações rápidas
    for (int i = 0; i < 50; ++i) {
        virtualMem.migrateBlockToTier(i % blocksLoaded, MemoryTier::Ram, -1)
            , virtualMem.migrateBlockToTier((i + 1) % blocksLoaded, MemoryTier::Vram, 0);
    }

    // Verifica se o thrashing foi detectado (deve ser true após muitas migrações rápidas)
    bool thrashingDetected = virtualMem.isThrashingDetected(50, 0.7); // Janela de 50, threshold 70%
    std::cout << "[DEMO RESULT] Thrashing detected: " << (thrashingDetected ? "YES" : "NO") << "\n ";

    // Teste de Prefetching
    std::cout << "\n [DEMO TEST] Testing Prefetching... ";
    virtualMem.prefetchBlocks({0, 1, 2}, MemoryTier::Vram);
    std::cout << "[DEMO RESULT] Prefetch completed.\n ";

    // Teste de Page Fault Simulation (para simular acesso a dados em pagefile)
    std::cout << "\n [DEMO TEST] Simulating Page Fault... ";
    virtualMem.simulatePageFault(1024 * 1024); // Endereço arbitrário
    std::cout << "[DEMO RESULT] Page fault handled.\n ";

    // Limpeza final
    std::remove(modelPath.c_str());
    return 0;
}
