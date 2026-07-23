#!/usr/bin/env python3
import re

with open('pesquisa/VirtualGpuMemory.cpp', 'r', encoding='utf-8') as f:
    content = f.read()

# Função original (com bug)
old_func = r'''void\* VirtualGpuMemory::mapPagefileView\(size_t offset, size_t size, DWORD accessFlags\) \{
    if \(!m_hPagefileMapping\) return nullptr;
    DWORD offsetHigh = static_cast<DWORD>\(offset >> 32\);
    DWORD offsetLow = static_cast<DWORD>\(offset & 0xFFFFFFFF\);
    return MapViewOfFile\(m_hPagefileMapping, accessFlags, offsetHigh, offsetLow, size\);'''

# Função corrigida (alinhando o offset)
new_func = '''void* VirtualGpuMemory::mapPagefileView(size_t offset, size_t size, DWORD accessFlags) {
    if (!m_hPagefileMapping) return nullptr;
    // CORREÇÃO CRÍTICA: Alinhar o offset à granularidade de alocação (64KB)
    size_t alignedOffset = alignPagefileOffset(offset);
    DWORD offsetHigh = static_cast<DWORD>(alignedOffset >> 32);
    DWORD offsetLow = static_cast<DWORD>(alignedOffset & 0xFFFFFFFF);
    return MapViewOfFile(m_hPagefileMapping, accessFlags, offsetHigh, offsetLow, size);'''

content = re.sub(old_func, new_func, content)

with open('pesquisa/VirtualGpuMemory.cpp', 'w', encoding='utf-8') as f:
    f.write(content)

print("Correção aplicada com sucesso!")
