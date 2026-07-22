# UMC — Unified Memory Core para Windows
## Especificação técnica de implementação (para entregar ao coder)

Objetivo do projeto: um serviço + biblioteca que corre em Windows, transparente para apps de IA (PyTorch, llama.cpp/GGML, etc.), que unifica VRAM + RAM + SSD num único espaço de endereçamento virtual "paginado", para eliminar erros Out-Of-Memory ao carregar modelos maiores que a VRAM disponível (ex: RTX 3060 12GB a correr modelos de 20-30GB).

Este documento está escrito para ser passado diretamente a um programador (humano ou agente tipo Claude Code). Cada secção é uma unidade de trabalho com critérios de aceitação claros.

---

## 0. Pré-requisitos que o coder deve ter instalados

- Visual Studio 2022 (workload "Desktop development with C++" + "Windows 10/11 SDK")
- CUDA Toolkit 12.6+ (para bater certo com o CUDA 12.6 já usado no ComfyUI portable do utilizador)
- CMake ≥ 3.28
- Python 3.10/3.11 (para o binding PyTorch) — usar pyenv-win, já existente no setup do utilizador
- Git

Hardware de referência para testes: AMD Ryzen 9 5950X, RTX 3060 12GB, 64GB RAM, NVMe. Isto é importante porque os limites de tiering devem ser calibrados para 12GB VRAM.

---

## 1. Arquitetura geral (visão de alto nível)

```
┌─────────────────────────────────────────────────────────┐
│  App IA (PyTorch / llama.cpp / ComfyUI custom node)     │
│      ↓ chama                                             │
│  umc_client.dll  (API pública, thin wrapper)             │
│      ↓ IPC (named pipe / shared memory)                  │
│  UMC Service (processo background, Win32 Service ou      │
│               tray app em modo utilizador)                │
│      ├─ Page Table Manager                               │
│      ├─ Tiering Engine (VRAM / RAM pinned / SSD)          │
│      ├─ Prefetch/Eviction Scheduler (thread pool)         │
│      └─ I/O Engine (OVERLAPPED / IOCP)                    │
└─────────────────────────────────────────────────────────┘
```

Decisão de design chave: **não tentar interceptar tudo ao nível do driver.** Em Windows, WDDM não permite gerir page faults de GPU em user-mode como em Linux (UVM). Por isso o UMC funciona como um **allocator explícito** que as apps adotam (via plugin PyTorch / backend GGML), e não como um driver transparente universal. Deixar isto claro ao utilizador final é importante para gerir expectativas.

---

## 2. Estruturas de dados centrais

### 2.1 `TensorPage`

```cpp
enum class MemoryTier : uint8_t {
    VRAM = 0,
    RAM_PINNED = 1,
    SSD = 2
};

struct TensorPage {
    uint64_t page_id;
    uint64_t tensor_id;          // a que tensor pertence
    size_t   offset_in_tensor;   // offset em bytes dentro do tensor lógico
    size_t   size_bytes;         // tipicamente 64MB, configurável
    MemoryTier current_tier;
    void*    vram_ptr   = nullptr;   // válido se current_tier == VRAM
    void*    ram_ptr    = nullptr;   // válido se current_tier == RAM_PINNED
    size_t   ssd_offset = 0;         // offset no ficheiro .umc/.safetensors
    std::atomic<uint32_t> refcount{0};
    std::atomic<uint64_t> last_access_tick{0}; // para LRU
    bool     dirty = false;      // se foi escrita e precisa de writeback
};
```

### 2.2 `TensorHandle` (o que a app vê)

```cpp
struct TensorHandle {
    uint64_t tensor_id;
    size_t   total_size_bytes;
    std::vector<uint64_t> page_ids; // ordenadas
    std::string source_file;        // path do .safetensors de origem
};
```

### 2.3 Page Table global

```cpp
class PageTable {
public:
    TensorPage* Lookup(uint64_t page_id);
    uint64_t    Insert(TensorPage page);
    void        UpdateTier(uint64_t page_id, MemoryTier new_tier, void* new_ptr);
    void        Touch(uint64_t page_id); // atualiza last_access_tick
private:
    std::unordered_map<uint64_t, TensorPage> table_;
    std::shared_mutex mutex_;
};
```

**Critério de aceitação da secção 2:** testes unitários que insiram 10.000 páginas, façam lookup concorrente de 8 threads, e validem que não há corrupção nem deadlock (usar Google Test + ThreadSanitizer).

---

## 3. Tiers de memória — implementação concreta em Windows

### 3.1 Tier 0 — VRAM

- Alocar com `cudaMalloc` para o pool fixo de páginas "quentes".
- **Não usar `cudaMallocManaged` como mecanismo principal** — em Windows/WDDM o comportamento de migração automática é pior e menos previsível do que em Linux. Usar apenas para os testes de spike (secção 6) para medir baseline, não para produção.
- Cópia RAM→VRAM: `cudaMemcpyAsync` em streams dedicados, nunca no stream default (para não bloquear compute).
- Reservar um "orçamento" de VRAM configurável (ex: 80% da VRAM livre detetada via `cudaMemGetInfo`), deixando margem para ativações/KV-cache da própria app.

### 3.2 Tier 1 — RAM pinned

- `cudaHostAlloc(&ptr, size, cudaHostAllocPortable)` para blocos pinned reutilizáveis (pool, não alocar/libertar a cada página — usar um allocator de slab).
- Manter um pool de N páginas pinned pré-alocadas (N calculado a partir da RAM livre, ex: reservar até 32GB dos 64GB do utilizador, configurável).
- Pinned memory é limitada — **não pinnar tudo**; usar pinned apenas como staging buffer para transferências rápidas, e RAM normal (`VirtualAlloc`) como tier intermédio "morno" se necessário (Tier 1b opcional).

### 3.3 Tier 2 — SSD/NVMe

- Formato de ficheiro: reaproveitar `.safetensors` diretamente (não reinventar formato) — ler o header JSON para saber offsets de cada tensor, e mapear páginas de 64MB dentro de cada tensor.
- I/O assíncrono via **I/O Completion Ports (IOCP)**, não `OVERLAPPED` isolado por thread — isto escala muito melhor com múltiplas leituras concorrentes.
- Abrir ficheiros com `FILE_FLAG_NO_BUFFERING | FILE_FLAG_OVERLAPPED` para bypass do cache do Windows quando os ficheiros são grandes (>VRAM), e alinhar leituras a 4KB (requisito do `NO_BUFFERING`).
- Fallback: se `NO_BUFFERING` complicar (alinhamento chato de implementar bem à primeira), começar sem essa flag e otimizar depois — não bloquear o MVP por causa disto.

**Critério de aceitação da secção 3:** benchmark que carregue um tensor de 4GB do SSD para RAM pinned e depois para VRAM, e reporte throughput em GB/s para cada transição. Meta mínima realista num NVMe Gen4 + PCIe4 RTX 3060: SSD→RAM ~2-3GB/s, RAM→VRAM ~10-12GB/s (PCIe4 x16 teórico ~16GB/s, x8 no 3060 tipicamente ~8GB/s — medir e documentar o valor real da máquina).

---

## 4. Prefetch / Eviction Scheduler

Esta é a peça que evita OOM e evita stalls.

### 4.1 Política de eviction
- LRU simples para o MVP (usar `last_access_tick` da `TensorPage`).
- Evoluir depois para "next-layer-aware": se a app sinalizar (via `umc_signal_layer_start(layer_id)`) qual a próxima camada do modelo a executar, o scheduler pode prefetch preditivo em vez de reativo.

### 4.2 Fluxo de execução
1. App pede acesso a uma página (`umc_get_page_ptr(tensor_id, page_index)`).
2. Se a página já está em VRAM → devolve ponteiro imediatamente.
3. Se está em RAM pinned → dispara `cudaMemcpyAsync` para VRAM, bloqueia a app só com um `cudaStreamSynchronize` mínimo, ou devolve um future/evento se a API o permitir.
4. Se está em SSD → dispara leitura assíncrona SSD→RAM pinned, depois RAM→VRAM. Aqui é onde a latência dói mais — por isso o prefetch preditivo da secção 4.1 é o que separa "funciona" de "funciona bem".
5. Sempre que uma página entra em VRAM e o orçamento de VRAM é excedido, o scheduler evicta a página LRU **antes** de aceitar a nova (nunca depois, para não estourar o orçamento mesmo que por instantes).

### 4.3 Threading
- Um thread pool dedicado a I/O (SSD), separado de um thread pool dedicado a cópias CUDA (streams).
- Usar uma queue lock-free (ex: `moodycamel::ConcurrentQueue`) para pedidos de página, para não bloquear o hot path do forward pass do modelo.

**Critério de aceitação da secção 4:** carregar um modelo de 20GB em safetensors numa GPU limitada artificialmente a 8GB (via `orçamento VRAM` configurável, não hardware), e completar um forward pass completo sem OOM, medindo overhead de latência vs. correr o mesmo modelo nativamente numa GPU com 24GB (ou simulado).

---

## 5. Integração com runtimes de IA

### 5.1 PyTorch (prioridade 1)
- Implementar um allocator customizado usando a API `c10::Allocator` / `CUDACachingAllocator` hooks do PyTorch (via `PYTORCH_CUDA_ALLOC_CONF` custom allocator, disponível desde PyTorch 2.x com `torch.cuda.memory.CUDAPluggableAllocator`).
- Exportar duas funções C compatíveis com essa API:
  ```cpp
  extern "C" void* umc_alloc(size_t size, int device, cudaStream_t stream);
  extern "C" void  umc_free(void* ptr, size_t size, int device, cudaStream_t stream);
  ```
- No lado Python, o utilizador ativa assim:
  ```python
  import torch
  from torch.cuda.memory import CUDAPluggableAllocator
  allocator = CUDAPluggableAllocator('umc_client.dll', 'umc_alloc', 'umc_free')
  torch.cuda.memory.change_current_allocator(allocator)
  ```
- Isto é o caminho **mais realista e mais rápido a dar resultados**, porque usa um mecanismo de extensão que já existe no PyTorch em vez de reescrever o `c10::Allocator` inteiro do zero.

### 5.2 llama.cpp / GGML (prioridade 2)
- Criar `ggml-backend-umc.c` seguindo o padrão dos backends existentes (`ggml-backend-cuda.cpp` como referência de interface).
- Implementar: `ggml_backend_umc_buffer_type()`, `alloc_buffer`, `get_tensor`, `set_tensor` — redirecionando pesos (não ativações) para o pager.
- Manter tensores temporários/ativações fora do UMC (deixar o alocador nativo da CUDA tratar disso) — só os **pesos do modelo** (que são estáticos e conhecidos antecipadamente) valem a pena passar pelo pager.

### 5.3 ComfyUI (caso de uso direto do utilizador)
- Como o ComfyUI usa PyTorch por baixo, a integração da secção 5.1 já cobre ComfyUI automaticamente, desde que seja ativada antes do `import comfy` (via variável de ambiente no `.bat` de arranque, ou patch no `main.py`).
- Não é preciso escrever nada específico do ComfyUI — é o caminho de menor esforço para o maior benefício prático imediato.

**Critério de aceitação da secção 5:** correr um workflow real de ComfyUI (ex: o pipeline Capybara/LTX Video já em uso) com o allocator UMC ativo, e confirmar visualmente nos logs que há evictions/prefetches acontecendo sem crash.

---

## 6. Plano de trabalho faseado (para o coder seguir por ordem)

### Fase 0 — Spike de validação (3-5 dias)
- Programa standalone em C++/CUDA: aloca 4GB com `cudaMallocManaged`, força prefetch com `cudaMemPrefetchAsync` em blocos de 64MB, mede latência.
- Programa standalone separado: `cudaHostAlloc` de 4GB + `cudaMemcpyAsync` para VRAM, medir throughput real da máquina (RTX 3060 + PCIe da motherboard do utilizador).
- **Entregável:** relatório com números reais de throughput (não estimativas) para as 3 transições: SSD→RAM, RAM→VRAM, RAM pageable→VRAM.

### Fase 1 — Page Table + Tiering básico (2-3 semanas)
- Implementar `PageTable`, `TensorPage`, allocator de slab para RAM pinned.
- Loader de `.safetensors` que mapeia tensores para páginas sem carregar tudo para memória.
- I/O síncrono simples primeiro (sem IOCP ainda) — só para provar o fluxo end-to-end.
- **Entregável:** carregar um ficheiro `.safetensors` de 10GB e conseguir ler qualquer tensor sob pedido, com o total de RAM usado pelo processo a ficar abaixo dos 10GB (prova de que não está tudo em memória ao mesmo tempo).

### Fase 2 — I/O assíncrono + Scheduler (2-3 semanas)
- Migrar I/O para IOCP.
- Implementar o Prefetch/Eviction Scheduler (secção 4).
- **Entregável:** o benchmark de OOM da secção 4 a passar.

### Fase 3 — Integração PyTorch (2 semanas)
- Implementar `CUDAPluggableAllocator` (secção 5.1).
- **Entregável:** um modelo real (ex: um checkpoint LTX Video ou similar já usado pelo utilizador) a carregar via PyTorch com o allocator UMC ativo, sem OOM, numa GPU cujo orçamento VRAM está artificialmente limitado.

### Fase 4 — Integração llama.cpp/GGML (1-2 semanas, opcional/paralelo)
- Secção 5.2.

### Fase 5 — Telemetria e polimento (1-2 semanas)
- Logs estruturados (page faults, evictions, tempo médio de prefetch).
- Uma UI mínima (mesmo que seja só uma janela de consola ou um tray icon) mostrando uso de VRAM/RAM/SSD em tempo real.

---

## 7. Riscos técnicos a comunicar já ao coder (para gerir expectativas)

1. **Latência de SSD é o gargalo real.** Mesmo com NVMe rápido, ler 20GB de um modelo do zero demora segundos — o ganho do UMC não é "zero overhead", é "funciona em vez de crashar", com penalização de latência que é aceitável para inferência batch mas pode ser notável em uso interativo.
2. **WDDM impõe limites que o Linux não tem.** Não vale a pena tentar replicar 1:1 técnicas de Linux (GPUDirect Storage, io_uring) — a arquitetura acima já assume isso e usa os equivalentes Windows corretos.
3. **PyTorch `CUDAPluggableAllocator` é relativamente recente e pode ter arestas.** Testar com a versão exata de PyTorch usada no ambiente do utilizador (verificar `torch.__version__` no venv do ComfyUI) antes de assumir compatibilidade total.
4. **SageAttention e outras extensões custom** que o utilizador já usa podem fazer alocações fora do allocator do PyTorch (via bindings CUDA diretos) — nesses casos o UMC não vê essas alocações. Vale a pena mapear isto cedo.

---

## 8. O que pedir ao coder entregar no final de cada fase

- Código no repositório com testes automatizados (Google Test para C++, pytest para o binding Python).
- Um `BENCHMARKS.md` com números reais medidos na máquina do utilizador (Ryzen 9 5950X / RTX 3060 12GB / 64GB RAM), não estimativas teóricas.
- Um `README.md` de arranque rápido explicando como ativar o UMC allocator num script Python existente (ex: no arranque do ComfyUI portable).
