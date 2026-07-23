#include <iostream>
#include "VirtualGpuMemory_simple.h"

int main() {
    VirtualGpuMemory vgm;
    if (!vgm.initialize()) {
        std::cerr << "Falha ao inicializar UMC!\n";
        return 1;
    }
    
    void* ptr = vgm.allocate(1024 * 1024); // 1MB
    if (!ptr) {
        std::cerr << "Falha ao alocar memória!\n";
        return 1;
    }
    
    std::cout << "Alocação bem-sucedida: " << vgm.getStats() << "\n";
    
    if (vgm.migrateToTier(ptr, VirtualGpuMemory::MemoryTier::Vram)) {
        std::cout << "Migração para VRAM simulada com sucesso!\n";
    }
    
    vgm.free(ptr);
    std::cout << "Memória libertada. UMC pronto para uso no ComfyUI!\n";
    return 0;
}