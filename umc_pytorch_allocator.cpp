#include "VirtualGpuMemory.h"

#if !defined(USE_CUDA_MOCK)
#include <cuda_runtime.h>
#endif

// Instância global da classe VirtualGpuMemory (para uso pelas funções C)
static VirtualGpuMemory* g_vgm = nullptr;

extern "C" {

// Função de alocação compatível com PyTorch CUDAPluggableAllocator
void* umc_alloc(size_t size, int device, cudaStream_t stream) {
    // Arredondar tamanho para múltiplo do blockSize (4MB por defeito)
    const size_t BLOCK_SIZE = 4 * 1024 * 1024; // 4MB
    size_t aligned_size = ((size + BLOCK_SIZE - 1) / BLOCK_SIZE) * BLOCK_SIZE;
    
    if (!g_vgm) {
        return nullptr;
    }
    
    // Tentar alocar na VRAM (device == GPU)
    if (device >= 0 && device < static_cast<int>(g_vgm->getGpuDevices().size())) {
        size_t blockId = g_vgm->estimateWorkingSet(1).first;
        BlockLocation loc;
        
        // Tenta alocar na VRAM
        if (g_vgm->allocateVram(blockId, loc)) {
            return reinterpret_cast<void*>(loc.physicalOffset);
        }
    }
    
    // Fallback para RAM se falhar VRAM
    BlockLocation loc;
    if (g_vgm->allocateRam(0, loc)) {  // blockId 0 como fallback
        return reinterpret_cast<void*>(loc.physicalOffset);
    }
    
    return nullptr; // Falha total
}

// Função de libertação compatível com PyTorch CUDAPluggableAllocator
void umc_free(void* ptr, size_t size, int device, cudaStream_t stream) {
    if (!ptr || !g_vgm) {
        return;
    }
    
    // Converter pointer para blockId (lógica simplificada)
    BlockLocation loc;
    for (size_t i = 0; i < 10000; ++i) {  // Busca linear (deve ser otimizada em produção)
        if (g_vgm->getBlockLocation(i, loc)) {
            if (loc.physicalOffset == reinterpret_cast<size_t>(ptr)) {
                g_vgm->freeBlockPhysical(i);
                break;
            }
        }
    }
}

// Função de inicialização do allocator
void umc_init_allocator(size_t maxVramBudget, size_t maxRamBudget) {
    if (g_vgm) {
        delete g_vgm;
    }
    
    g_vgm = new VirtualGpuMemory(
        4 * 1024 * 1024,      // blockSizeBytes: 4MB
        maxVramBudget,         // maxVramBudget (0 = ilimitado)
        maxRamBudget,          // maxRamBudget (0 = ilimitado)
        0                      // maxPagefileBudget (não usar pagefile por enquanto)
    );
    
    if (!g_vgm->initialize()) {
        delete g_vgm;
        g_vgm = nullptr;
    }
}

// Função de limpeza do allocator
void umc_cleanup_allocator() {
    if (g_vgm) {
        delete g_vgm;
        g_vgm = nullptr;
    }
}

} // extern "C"
