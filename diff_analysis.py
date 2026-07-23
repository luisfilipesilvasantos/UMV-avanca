# Análise de diffs entre VirtualGpuMemory.cpp (atual) e VirtualGpuMemory-Nemotron-Fixed.cpp

def extract_function(content, func_name):
    start = content.find(func_name)
    if start == -1:
        return None
    brace_start = content.find('{', start)
    if brace_start == -1:
        return None
    depth = 0
    end = brace_start
    for i in range(brace_start, len(content)):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    return content[start:end]

# Ler os arquivos
content_current = open('VirtualGpuMemory.cpp', 'r', encoding='utf-8').read()
try:
    content_nemotron = open('VirtualGpuMemory-Nemotron-Fixed.cpp', 'r', encoding='utf-8').read()
except FileNotFoundError:
    print("Erro: Arquivo VirtualGpuMemory-Nemotron-Fixed.cpp não encontrado.")
    exit(1)

funcs_to_compare = [
    ('Constructor', 'VirtualGpuMemory::VirtualGpuMemory('),
    ('Destructor', 'VirtualGpuMemory::~VirtualGpuMemory()'),
    ('Initialize', 'bool VirtualGpuMemory::initialize()'),
    ('Cleanup', 'void VirtualGpuMemory::cleanup()')
]

print("="*80)
print("ANÁLISE DE DIFERENÇAS: VirtualGpuMemory.cpp vs VirtualGpuMemory-Nemotron-Fixed.cpp")
print("="*80)

for name, func in funcs_to_compare:
    current = extract_function(content_current, func)
    nemotron = extract_function(content_nemotron, func)
    
    if not current or not nemotron:
        print(f"\n=== {name} ===")
        print("ERRO: Função não encontrada em um dos arquivos.")
        continue
    
    # Normalizar espaços e comentários para comparação básica
    def normalize(s):
        return ' '.join(line.strip() for line in s.splitlines() if line.strip())
    
    norm_current = normalize(current)
    norm_nemotron = normalize(nemotron)
    
    print(f"\n{'='*80}")
    print(f"FUNÇÃO: {name}")
    print("="*80)
    
    # Comparar linhas
    lines_current = current.splitlines()
    lines_nemotron = nemotron.splitlines()
    
    max_lines = max(len(lines_current), len(lines_nemotron))
    for i in range(max_lines):
        curr_line = lines_current[i] if i < len(lines_current) else ""
        nemo_line = lines_nemotron[i] if i < len(lines_nemotron) else ""
        
        if curr_line != nemo_line:
            print(f"[DIFERENÇA]")
            if curr_line.strip():
                print(f"  Atual:      {curr_line[:100]}")
            if nemo_line.strip():
                print(f"  Nemotron:   {nemo_line[:100]}")
        else:
            # Mostrar apenas se for significativo
            if curr_line.strip() and not curr_line.strip().startswith('//'):
                pass  # Ignorar linhas em branco e comentários para brevidade
    
    print("\n[RESUMO DAS DIFERENÇAS]")
    
    # Verificar problemas específicos mencionados no prompt
    if 'L"pagefile_mapping.dat"' in nemotron:
        print("  - PROBLEMA CRÍTICO: Uso de L\"pagefile_mapping.dat\" (wide string) sem UNICODE definido.")
    
    # Verificar se há "}" solto antes do construtor
    if name == 'Constructor':
        nemotron_before = content_nemotron[:content_nemotron.find('VirtualGpuMemory::VirtualGpuMemory(')]
        open_braces = nemotron_before.count('{')
        close_braces = nemotron_before.count('}')
        if close_braces > open_braces:
            print(f"  - PROBLEMA CRÍTICO: {close_braces - open_braces}}}' solto(s) antes do construtor.")
    
    # Verificar lógica de orçamento
    if name == 'Initialize':
        has_budget_calc = '80%' in current and '50%' in current
        nemo_has_budget_calc = '80%' in nemotron and '50%' in nemotron
        
        print(f"  - Orçamento dinâmico (80% VRAM, 50% RAM): Atual={has_budget_calc}, Nemotron={nemo_has_budget_calc}")
        if not nemo_has_budget_calc:
            print("    PERDA: O Nemotron-Fixed usa valores fixos do construtor sem margem de segurança.")
        
        has_streams = 'm_streams' in current
        nemo_has_streams = 'm_streams' in nemotron
        print(f"  - Criação de streams CUDA por GPU: Atual={has_streams}, Nemotron={nemo_has_streams}")
        if not nemo_has_streams:
            print("    PERDA: O Nemotron-Fixed não cria streams CUDA.")
    
    # Verificar cleanup
    if name == 'Cleanup':
        has_system_allocs = 'm_systemAllocations' in current
        nemo_has_system_allocs = 'm_systemAllocations' in nemotron
        print(f"  - Liberação de m_systemAllocations: Atual={has_system_allocs}, Nemotron={nemo_has_system_allocs}")
        if not nemo_has_system_allocs:
            print("    PERDA CRÍTICA: O Nemotron-Fixed não libera alocações em pagefile (UnmapViewOfFile/CloseHandle).")
        
        has_streams_cleanup = 'm_streams' in current and 'cudaStreamDestroy' in current
        nemo_has_streams_cleanup = 'm_streams' in nemotron and 'cudaStreamDestroy' in nemotron
        print(f"  - Destruição de streams CUDA: Atual={has_streams_cleanup}, Nemotron={nemo_has_streams_cleanup}")
        if not nemo_has_streams_cleanup:
            print("    PERDA: O Nemotron-Fixed não limpa as streams CUDA.")

print("\n" + "="*80)
print("VERIFICAÇÃO DE HEADERS")
print("="*80)
if 'nvml_mock.h' in content_nemotron and 'cuda_runtime_mock.h' in content_nemotron:
    print("O ficheiro VirtualGpuMemory-Nemotron-Fixed.cpp usa nvml_mock.h e cuda_runtime_mock.h.")
    print("Isso indica que é uma variante para desenvolvimento sem CUDA Toolkit instalado (modo mock).")
    print("NÃO deve ser fundida com o ficheiro de produção, deve ficar arquivada como referência.")
elif '<nvml.h>' in content_nemotron or '<cuda_runtime.h>' in content_nemotron:
    print("O ficheiro VirtualGpuMemory-Nemotron-Fixed.cpp usa headers reais do CUDA Toolkit.")
else:
    print("Não foi possível determinar os headers usados pelo Nemoton-Fixed.")