#!/usr/bin/env python3
import re

def find_truncated_strings(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    errors = []
    for i, line in enumerate(lines, 1):
        # Conta aspas duplas — se ímpar, há string não fechada
        if line.count('"') % 2 == 1:
            # Ignora casos onde " está dentro de comentário (começa com //)
            code_part = line.split('//')[0] if '//' in line else line
            if code_part.count('"') % 2 == 1:
                errors.append((i, line.rstrip()))
    
    return errors

if __name__ == '__main__':
    filepath = r'temp_extract\\VirtualGpuMemory.cpp'
    errors = find_truncated_strings(filepath)
    if not errors:
        print("Nenhuma string truncada encontrada.")
    else:
        print(f"Encontradas {len(errors)} strings não fechadas:")
        for line_num, content in errors[:10]:  # Mostra até 10
            print(f"Linha {line_num}: {content}")