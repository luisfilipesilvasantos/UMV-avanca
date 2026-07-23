#!/usr/bin/env python3
with open('VirtualGpuMemory.h', 'r') as f:
    content = f.read()

# Encontrar a última ocorrência de '}\n'
target = "};"
idx = content.rfind(target)
if idx == -1:
    raise ValueError("Não encontrei '};' no ficheiro")

# Inserir antes do fecho
insert_text = '''    // Métodos de estatísticas de memória virtual
    size_t getTotalBytes() const;
    size_t getAllocatedBytes() const;
    size_t getHostAllocatedBytes() const;
    size_t getDeviceAllocatedBytes(int deviceId) const;
'''

new_content = content[:idx] + insert_text + content[idx:]

with open('VirtualGpuMemory.h', 'w') as f:
    f.write(new_content)

print("Declarações adicionadas com sucesso!")