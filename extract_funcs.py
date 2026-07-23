#!/usr/bin/env python3
import re

def extract_function(content, pattern):
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(0)[:2500]  # Limita a 2500 chars para legibilidade
    return "NÃO ENCONTRADA"

def main():
    with open('VirtualGpuMemory.cpp', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    patterns = [
        (r'VirtualGpuMemory::VirtualGpuMemory\s*\([^)]*\)\s*[\s:]*[^{]*\{(?:[^{}]|\{[^{}]*\})*\}', 'Constructor'),
        (r'VirtualGpuMemory::~VirtualGpuMemory\s*\(\s*\)\s*[^{]*\{(?:[^{}]|\{[^{}]*\})*\}', 'Destructor'),
        (r'bool VirtualGpuMemory::initialize\s*\(\s*\)\s*[^{]*\{(?:[^{}]|\{[^{}]*\})*\}', 'Initialize'),
        (r'void VirtualGpuMemory::cleanup\s*\(\s*\)\s*[^{]*\{(?:[^{}]|\{[^{}]*\})*\}', 'Cleanup')
    ]
    
    for pattern, name in patterns:
        print(f"\n=== {name} ===")
        result = extract_function(content, pattern)
        if len(result) == 2500:
            print(result + "... [TRUNCADO]")
        else:
            print(result)

if __name__ == '__main__':
    main()
