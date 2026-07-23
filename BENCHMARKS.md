# UMC — BENCHMARKS.md
## Resultados reais da Fase 0 (spikes de validação)

**Hardware:** AMD Ryzen 9 5950X, NVIDIA GeForce RTX 3060 12GB, 64GB RAM, Windows.
**Software:** CUDA Toolkit 13.3, MSVC 19.44 (VS 2022 Community), CMake 4.3, `sm_86`.
**Data:** Julho 2026.

---

### Spike 1 — `spike_managed_memory` (cudaMallocManaged + cudaMemPrefetchAsync)

| Atributo | Valor |
|---|---|
| `concurrentManagedAccess` | **NAO** |
| `pageableMemoryAccess` | **NAO** |
| Resultado do prefetch CPU→GPU | Falhou imediatamente: `invalid device ordinal` |

**Conclusão (decisão de arquitetura validada):** `cudaMallocManaged` + `cudaMemPrefetchAsync` **não é um caminho viável** para o UMC em produção, neste hardware e sistema operativo. A RTX 3060 em Windows/WDDM não expõe o mecanismo de page-fault de Unified Memory que o driver Linux disponibiliza em GPUs equivalentes — por isso a migração automática de memória gerida simplesmente não funciona aqui, independentemente de código ou configuração.

Isto **confirma** a decisão já prevista no documento de arquitetura (`UMC_Windows_Spec_Implementacao.md`, secção 3.1): o UMC deve usar tiering **explícito** via `cudaHostAlloc` + `cudaMemcpyAsync`, nunca depender de Unified Memory automática.

---

### Spike 2 — `spike_host_pinned_memory` (cudaHostAlloc + cudaMemcpyAsync)

Buffer de teste: 4GB, blocos de 64MB.

| Método | H2D (GB/s) | D2H (GB/s) |
|---|---|---|
| **Pinned (cudaHostAlloc)** | **10.80** | **12.27** |
| Pageable (malloc) | 7.63 | 9.08 |

**Speedup pinned vs. pageable:** 1.42x (H2D), 1.35x (D2H).

**Conclusão:** o mecanismo de tiering pinned funciona corretamente e com bom throughput neste hardware. O ganho de ~40% sobre pageable confirma que vale a pena a complexidade extra de gerir um pool de pinned memory no UMC (Tier 1 do documento de arquitetura).

**Estimativas derivadas para planeamento:**
- Mover um modelo de 20GB de RAM pinned para VRAM: ≈ 20 / 10.8 ≈ **1.85 segundos**.
- Mover o mesmo de volta (VRAM → RAM): ≈ 20 / 12.27 ≈ **1.63 segundos**.
- Estes valores não incluem a leitura do SSD para RAM, que é o próximo gargalo a medir (fica para a Fase 1, ao implementar o loader de `.safetensors`).

---

### Decisão de arquitetura confirmada para as próximas fases

O core do UMC (Fase 1 em diante, conforme `UMC_Windows_Spec_Implementacao.md`) deve assentar inteiramente em:
- **Tier 0 (VRAM):** `cudaMalloc` + streams dedicados.
- **Tier 1 (RAM pinned):** `cudaHostAlloc` com pool de slabs reutilizáveis.
- **Transferências:** sempre `cudaMemcpyAsync` explícito, nunca prefetch de Unified Memory.

Isto simplifica também o `CMakeLists.txt` e os testes futuros — não há necessidade de manter caminho de código para `cudaMallocManaged`, o que reduz a superfície de complexidade do projeto.
