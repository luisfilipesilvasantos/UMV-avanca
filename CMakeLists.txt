cmake_minimum_required(VERSION 3.28)
project(UMC VERSION 1.0.0 LANGUAGES CXX)

# Modern CUDA detection (replaces deprecated find_package(CUDA))
find_package(CUDAToolkit REQUIRED)

# Definir biblioteca dinâmica
add_library(UMC SHARED
    umc_client.cpp
    VirtualGpuMemory.cpp
    umc_pytorch_allocator.cpp
    umc_hook.cpp
    umc.def
)

# Incluir diretório do projeto para headers locais
target_include_directories(UMC PRIVATE ${PROJECT_SOURCE_DIR})

# Configurar padrão C++17 (necessário para structured bindings)
set_target_properties(UMC PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)

# Configurar compilação para Windows
set_target_properties(UMC PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS OFF
    POSITION_INDEPENDENT_CODE ON
)

# Adicionar diretório de libs CUDA para encontrar nvml.lib
target_link_directories(UMC PRIVATE ${CUDAToolkit_LIBRARY_DIR})

# Link com bibliotecas necessárias
target_link_libraries(UMC PRIVATE
    CUDA::cudart
    nvml.lib
    psapi.lib
    kernel32.lib
    user32.lib
    gdi32.lib
    winspool.lib
    shell32.lib
    ole32.lib
    oleaut32.lib
    uuid.lib
    comdlg32.lib
    advapi32.lib
)

# Configurar saída para pasta bin/
set_target_properties(UMC PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/bin
)
