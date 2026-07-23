import re

# Ler o ficheiro original
with open('VirtualGpuMemory.cpp', 'r') as f:
    content = f.read()

lines = content.split('\n')

# 1. Remover a função tierToString (linhas entre 'std::string tierToString' e o fecho '}')
in_tier_to_string = False
tier_start_line = -1
for i, line in enumerate(lines):
    if 'std::string tierToString(MemoryTier tier)' in line:
        tier_start_line = i
        in_tier_to_string = True
        break

if tier_start_line >= 0:
    # Encontrar o fim da função (linha com '}')
    brace_count = 0
    tier_end_line = -1
    for i in range(tier_start_line, len(lines)):
        line_stripped = lines[i].strip()
        brace_count += line_stripped.count('{') - line_stripped.count('}')
        if brace_count == 0 and '}' in line_stripped:
            tier_end_line = i
            break
    
    # Remover as linhas da função tierToString (incluindo a linha de definição e o fecho)
    if tier_end_line >= 0:
        del lines[tier_start_line:tier_end_line+1]
        print(f"Removida função tierToString das linhas {tier_start_line} a {tier_end_line}")

# 2. Corrigir lock_guard na linha ~147 (ou onde ocorra)
for i in range(len(lines)):
    if 'lock_guard' in lines[i]:
        # Substituir qualquer menção errada por std::recursive_mutex e m_mutex
        lines[i] = re.sub(r'std::mutex', 'std::recursive_mutex', lines[i])
        lines[i] = re.sub(r'm_lock|lock\)', 'm_mutex', lines[i])
        # Garantir que está exatamente como: std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if 'lock_guard' in lines[i]:
            lines[i] = 'std::lock_guard<std::recursive_mutex> lock(m_mutex);'
        print(f"Corrigido lock_guard na linha {i+1}: {lines[i].strip()}")

# 3. Verificar e corrigir prefixos de funções (funções definidas fora da classe)
# Procurar por definições de função que não tenham VirtualGpuMemory::
for i in range(len(lines)):
    line = lines[i].strip()
    # Ignorar comentários e diretivas
    if line.startswith('//') or line.startswith('#') or not line:
        continue
    
    # Padrão para capturar definições de função sem prefixo (ex: 'void freeSystemVirtual(...)' ou 'bool allocate(...)')
    match = re.match(r'^(\w+)\s+(\w+)\s*\(', line)
    if match:
        return_type, func_name = match.groups()
        # Ignorar funções que já têm prefixo
        if '::' in func_name or 'VirtualGpuMemory::' + func_name in content:
            continue
        
        # Verificar se é uma função declarada em VirtualGpuMemory.h (para evitar corrigir funções auxiliares)
        # Como não temos o header, vamos assumir que todas as funções definidas aqui devem ter prefixo
        # Exceção: construtor/destrutor já têm prefixo
        if func_name not in ['VirtualGpuMemory', '~VirtualGpuMemory']:
            # Verificar se a linha anterior tem 'bool'/'void'/'int'/etc. e não tem '::'
            prev_line = lines[i-1].strip() if i > 0 else ''
            if return_type in ['void', 'bool', 'size_t', 'int', 'float', 'double', 'char*', 'std::string'] and not '::' in line:
                # Tentar corrigir adicionando prefixo
                lines[i] = re.sub(rf'^({return_type})\s+({func_name}\s*\()', rf'\1 VirtualGpuMemory::{func_name}\2', lines[i])
                print(f"Corrigido prefixo na linha {i+1}: {lines[i].strip()}")

# Escrever o ficheiro modificado
with open('VirtualGpuMemory.cpp', 'w') as f:
    f.write('\n'.join(lines))

print("Processamento concluído.")