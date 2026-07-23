# Script para proteger funções CUDA no VirtualGpuMemory.cpp
import re

with open('VirtualGpuMemory.cpp', 'r') as f:
    content = f.read()

# Funções dependentes de CUDA (com assinatura completa)
cuda_function_signatures = [
    r'cudaStream_t\s+VirtualGpuMemory::getOrCreateStream\(int deviceId\)',
    r'bool\s+VirtualGpuMemory::writeBlockAsync\([^)]+\)',
    r'void\s+VirtualGpuMemory::synchronizeStream\([^)]+\)',
    r'void\s+VirtualGpuMemory::synchronizeAllStreams\(\)',
]

# Encontrar todas as ocorrências de funções CUDA e envolvê-las com #ifdef USE_CUDA
# Vamos fazer isso manualmente, linha por linha, para garantir precisão.

lines = content.split('\n')
output_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Detectar início de função CUDA
    if 'cudaStream_t VirtualGpuMemory::getOrCreateStream(int deviceId)' in line:
        output_lines.append('#ifndef USE_CUDA')
        output_lines.append('cudaStream_t VirtualGpuMemory::getOrCreateStream(int deviceId) { return nullptr; }')
        output_lines.append('#else')
        i += 1
        # Copiar corpo da função até encontrar o próximo '}' (ou fechar com #endif)
        brace_count = 0
        while i < len(lines):
            line = lines[i]
            if '{' in line:
                brace_count += line.count('{')
            if '}' in line:
                brace_count -= line.count('}')
                if brace_count == -1:  # Fim da função
                    output_lines.append(line)
                    i += 1
                    break
            output_lines.append(line)
            i += 1
        output_lines.append('#endif')
    
    elif 'bool VirtualGpuMemory::writeBlockAsync(size_t blockId, const void* data, size_t size, cudaStream_t stream)' in line:
        output_lines.append('#ifndef USE_CUDA')
        output_lines.append('bool VirtualGpuMemory::writeBlockAsync(size_t blockId, const void* data, size_t size, cudaStream_t stream) { return false; }')
        output_lines.append('#else')
        i += 1
        brace_count = 0
        while i < len(lines):
            line = lines[i]
            if '{' in line:
                brace_count += line.count('{')
            if '}' in line:
                brace_count -= line.count('}')
                if brace_count == -1:
                    output_lines.append(line)
                    i += 1
                    break
            output_lines.append(line)
            i += 1
        output_lines.append('#endif')
    
    elif 'void VirtualGpuMemory::synchronizeStream(cudaStream_t stream)' in line:
        output_lines.append('#ifndef USE_CUDA')
        output_lines.append('void VirtualGpuMemory::synchronizeStream(cudaStream_t stream) {}')
        output_lines.append('#else')
        i += 1
        brace_count = 0
        while i < len(lines):
            line = lines[i]
            if '{' in line:
                brace_count += line.count('{')
            if '}' in line:
                brace_count -= line.count('}')
                if brace_count == -1:
                    output_lines.append(line)
                    i += 1
                    break
            output_lines.append(line)
            i += 1
        output_lines.append('#endif')
    
    elif 'void VirtualGpuMemory::synchronizeAllStreams()' in line:
        output_lines.append('#ifndef USE_CUDA')
        output_lines.append('void VirtualGpuMemory::synchronizeAllStreams() {}')
        output_lines.append('#else')
        i += 1
        brace_count = 0
        while i < len(lines):
            line = lines[i]
            if '{' in line:
                brace_count += line.count('{')
            if '}' in line:
                brace_count -= line.count('}')
                if brace_count == -1:
                    output_lines.append(line)
                    i += 1
                    break
            output_lines.append(line)
            i += 1
        output_lines.append('#endif')
    
    else:
        output_lines.append(line)
        i += 1

# Escrever o resultado
with open('VirtualGpuMemory.cpp', 'w') as f:
    f.write('\n'.join(output_lines))

print('Ficheiro VirtualGpuMemory.cpp atualizado com proteção CUDA.')