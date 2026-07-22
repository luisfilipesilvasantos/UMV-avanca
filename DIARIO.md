# Diário de Progresso — UMC (Unified Memory Controller)

Este ficheiro é o histórico de decisões e progresso do projeto.
Lê sempre a entrada mais recente antes de continuares o trabalho.

---

## Decisões tomadas e porquê

- **Confirmado com evidência bruta (conteúdo de VirtualGpuMemory.h e cuda_runtime_mock.h, mais findstr com números de linha): MemoryTier, BlockLocation e GpuDeviceInfo estão definidos apenas em VirtualGpuMemory.h. cuda_runtime_mock.h já não os redefine. Não há conflito de redefinição entre estes dois ficheiros.**
  - *Porquê*: A verificação direta do conteúdo dos headers (com grep/findstr e números de linha) mostrou que as definições únicas de `enum class MemoryTier`, `struct BlockLocation` e `struct GpuDeviceInfo` ocorrem exclusivamente em VirtualGpuMemory.h. O cuda_runtime_mock.h contém apenas stubs para CUDA (cudaStream_t, cudaError_t, etc.) sem redefinir estes tipos críticos.

- **VirtualGpuMemory-Nemotron-Fixed.cpp era só referência, não para integrar. Arquivado em /archive/reference-only/. O trabalho continua exclusivamente em VirtualGpuMemory.cpp.**
  - *Porquê*: Este ficheiro foi fornecido apenas como inspiração/exemplo de implementação, nunca como candidato a fusão no projeto. Para evitar confusões futuras e manter o histórico limpo, foi movido para /archive/reference-only/.

- **Verificação da redefinição de tipos (MemoryTier, BlockLocation, GpuDeviceInfo): não há conflito entre VirtualGpuMemory.h e cuda_runtime_mock.h.**
  - *Porquê*: Após grep em todos os headers do projeto (`*.h`), confirmou-se que `enum class MemoryTier`, `struct BlockLocation` e `struct GpuDeviceInfo` só são definidos em VirtualGpuMemory.h (e backups). O cuda_runtime_mock.h apenas define tipos CUDA stubs (cudaStream_t, cudaError_t) e funções mockadas. Portanto, não há conflito real a resolver entre estes dois headers canónicos.

- **Revisão de código útil no ficheiro VirtualGpuMemory-Nemotron.cpp: não há funcionalidades adicionais para integrar.**
  - *Porquê*: O ficheiro Nemotron tem apenas 194 linhas, é uma versão incompleta/resumida do VirtualGpuMemory.cpp (que tem milhares de linhas). A implementação canónica já cobre todas as funcionalidades principais: inicialização NVML/ram/pagefile, alocação/migração/eviction de blocos, deteção de thrashing, histórico de residência e prefetching. Não há código útil adicional para extrair.

- **Fase 0 — Verificação dos ficheiros backup/alternativos (2025-04-05):**
  - *VirtualGpuMemory_backup.h*: Contém as mesmas definições de MemoryTier, BlockLocation e outras estruturas que VirtualGpuMemory.h. Não há conflito se não for incluído juntamente com o header principal.
  - *virtualgpumemory_header.cpp*: É na verdade um header (apesar do nome .cpp) com as mesmas definições de tipos e declaração de funções adicionais (writeBlockAsync, synchronizeStream). Não contém implementações — apenas declarações. Se incluído juntamente com VirtualGpuMemory.h, causaria conflito; por isso deve ser arquivado.
  - *virtualgpumemory_implementatio.cpp* e *virtualgpumemory_implementation.cpp*: Implementações parciais que incluem VirtualGpuMemory.h (sem redefinir tipos). Contêm as mesmas funções básicas do VirtualGpuMemory.cpp, mas são incompletas ou desatualizadas. Arquivar.
  - *virtualgpumemory_implementation_patched.cpp*: Implementação com funções adicionais não presentes no VirtualGpuMemory.cpp atual: writeBlockAsync (cópia assíncrona Host-to-Device via cudaStream) e synchronizeStream (sincronização de stream CUDA). Estas funções podem ser integradas ao código principal. **Decisão**: Adicionar declarações no header VirtualGpuMemory.h e implementações no VirtualGpuMemory.cpp antes de arquivar este ficheiro.

- **Fase 0 — Arquivação dos ficheiros redundantes (2025-04-05):**
  - *VirtualGpuMemory_backup.h*, *virtualgpumemory_header.cpp*, *virtualgpumemory_implementatio.cpp* e *virtualgpumemory_implementation.cpp*: Todos arquivados em /archive/backup-old/. Não trazem funcionalidades novas ou correcções críticas.
  - *virtualgpumemory_implementation_patched.cpp*: Funções writeBlockAsync e synchronizeStream foram integradas ao VirtualGpuMemory.h e VirtualGpuMemory.cpp. O ficheiro foi arquivado em /archive/backup-old/.

- **[2025-04-05] Investigação de erro de compilação no VirtualGpuMemory.cpp (linha 862): identificação de problema de chaves faltando na função getAvailableVram.**
  - *Porquê*: Ao tentar compilar, ocorreu um erro relacionado à linha 862 do VirtualGpuMemory.cpp. A leitura direta das linhas ao redor da linha 862 revelou que a implementação de `getAvailableVram` está incompleta ou com chaves desbalanceadas.

---