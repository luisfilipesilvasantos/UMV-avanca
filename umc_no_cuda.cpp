#include <iostream>

#include "VirtualGpuMemory.h"

int main() {
    std::cout << "Testing VirtualGpuMemory without CUDA..." << std::endl;

    try {
        // Cria uma instância com blocos de 4MB
        VirtualGpuMemory vgm(4 * 1024 * 1024);

        // Inicializa o sistema
        if (!vgm.initialize()) {
            std::cerr << "Failed to initialize VirtualGpuMemory" << std::endl;
            return -1;
        }

        std::cout << "VirtualGpuMemory initialized successfully." << std::endl;
        std::cout << "Total virtual capacity: " << vgm.getTotalVirtualCapacity() << " bytes" << std::endl;
        std::cout << "Block size: " << vgm.getBlockSize() << " bytes" << std::endl;

        // Exibe informações das GPUs (se disponíveis)
        const auto& devices = vgm.getGpuDevices();
        if (!devices.empty()) {
            for (const auto& dev : devices) {
                std::cout << "GPU Device [" << dev.deviceId << "]: " << dev.name
                          << " - VRAM: " << dev.totalVram << " bytes" << std::endl;
            }
        } else {
            std::cout << "No CUDA-capable GPU detected. Using CPU/RAM fallback." << std::endl;
        }

        // Exibe informações de RAM e Pagefile
        std::cout << "Total Host RAM: " << vgm.getTotalHostRam() << " bytes" << std::endl;
        std::cout << "Available Host RAM: " << vgm.getAvailableHostRam() << " bytes" << std::endl;
        std::cout << "Total Pagefile: " << vgm.getTotalPagefile() << " bytes" << std::endl;
        std::cout << "Available Pagefile: " << vgm.getAvailablePagefile() << " bytes" << std::endl;

        // Teste simples de alocação e acesso — buffers alocados na heap com std::vector
        const size_t numBlocks = 10;
        std::vector<char> buffer(4 * 1024 * 1024);
        std::vector<char> readBuffer(4 * 1024 * 1024);
        for (size_t i = 0; i < numBlocks; ++i) {
            std::memset(buffer.data(), static_cast<char>(i), buffer.size());

            if (!vgm.writeBlock(i, buffer.data(), vgm.getBlockSize())) {
                std::cerr << "Failed to write block " << i << std::endl;
                return -1;
            }

            if (!vgm.readBlock(i, readBuffer.data(), vgm.getBlockSize())) {
                std::cerr << "Failed to read block " << i << std::endl;
                return -1;
            }

            bool match = (std::memcmp(buffer.data(), readBuffer.data(), buffer.size()) == 0);
            std::cout << "Block " << i << ": Write/Read test " << (match ? "PASSED" : "FAILED") << std::endl;
        }

        // Dump do layout de blocos
        vgm.dumpLayout();

        std::cout << "Test completed successfully." << std::endl;
        return 0;
    } catch (const std::exception& ex) {
        std::cerr << "Exception caught: " << ex.what() << std::endl;
        return -1;
    }
}
