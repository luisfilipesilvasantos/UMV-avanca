#!/usr/bin/env python3
"""Extrai funções específicas do VirtualGpuMemory-Nemotron-Fixed.cpp."""

def find_function(content, func_name):
    """Encontra a definição da função e seu corpo (entre chaves balanceadas)."""
    idx = content.find(func_name)
    if idx == -1:
        return None
    
    paren_depth = 0
    brace_start = -1
    for i in range(idx, min(len(content), idx + 2000)):
        if content[i] == '(':
            paren_depth += 1
        elif content[i] == ')':
            paren_depth -= 1
        elif content[i] == '{' and paren_depth == 0:
            brace_start = i
            break
    
    if brace_start == -1:
        return None
    
    depth = 1
    for i in range(brace_start + 1, len(content)):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                return content[brace_start:i+1]
    
    return None

def main():
    with open('VirtualGpuMemory-Nemotron-Fixed.cpp', 'r') as f:
        content = f.read()
    
    functions = [
        ('VirtualGpuMemory::VirtualGpuMemory(', 'Constructor'),
        ('VirtualGpuMemory::~VirtualGpuMemory(', 'Destructor'),
        ('bool VirtualGpuMemory::initialize(', 'Initialize'),
        ('void VirtualGpuMemory::cleanup(', 'Cleanup')
    ]
    
    for func_sig, name in functions:
        result = find_function(content, func_sig)
        print(f"\n=== {name} ===")
        if result:
            display = (result[:2500] + "... [TRUNCADO]") if len(result) > 2500 else result
            print(display)
        else:
            print("NÃO ENCONTRADA")

if __name__ == '__main__':
    main()
