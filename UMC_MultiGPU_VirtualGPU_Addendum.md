# UMC — Adenda: Virtual GPU Multi-GPU
## Extensão da especificação para orquestração de múltiplas GPUs + tiering RAM/SSD

Este documento estende `UMC_Windows_Spec_Implementacao.md`. Não substitui o core do UMC (Page Table, tiering VRAM/RAM/SSD) — acrescenta uma camada por cima que trata **múltiplas GPUs como um único dispositivo lógico**. Ler o documento base primeiro; este assume que as Fases 0-2 de lá já existem.

**Nota de expectativas para o utilizador, antes de tudo:** isto não vai ser um "SLI para IA" mágico. Não existe forma de fazer o Windows/CUDA ver duas GPUs como uma sem custo — cada byte que atravessa de uma GPU para outra paga o preço do PCIe (e sem NVLink, isso é lento comparado com acesso local à VRAM). O valor real disto não é "2x mais rápido com 2 GPUs", é "consegues correr um modelo que não cabia em nenhuma das duas sozinha, e as duas cooperam em vez de estarem cada uma limitada ao seu próprio silo".

---

## 1. O que muda em relação ao UMC base

| Conceito UMC base | Extensão Virtual GPU |
|---|---|
| `TensorPage.current_tier` = VRAM / RAM / SSD | passa a incluir `gpu_id` quando `tier == VRAM` |
| Um único contexto CUDA (`cudaSetDevice(0)`) | um contexto CUDA por GPU física, geridos pelo `GpuPoolManager` |
| Scheduler decide só VRAM↔RAM↔SSD | Scheduler decide também **em qual GPU** colocar cada página |
| PyTorch vê 1 device custom | PyTorch continua a ver **1 device lógico** (`umc_virtual`); a divisão por GPU física é invisível para o utilizador do modelo |

---

## 2. GPU Pool Discovery & Topology

No arranque do serviço UMC:

```cpp
struct GpuInfo {
    int         device_index;      // índice CUDA (cudaSetDevice)
    std::string name;              // ex: "NVIDIA GeForce RTX 3060"
    size_t      total_vram_bytes;
    size_t      free_vram_bytes;   // via cudaMemGetInfo
    int         pcie_gen;
    int         pcie_link_width;   // via nvmlDeviceGetCurrPcieLinkWidth
    bool        nvlink_available;  // via NVML, quase certamente false neste setup
};

class GpuPoolManager {
public:
    void Discover();                 // enumera via cudaGetDeviceCount + NVML
    std::vector<GpuInfo> GetPool() const;
    size_t TotalVramAcrossPool() const;
private:
    std::vector<GpuInfo> gpus_;
};
```

- Usar **NVML** (`nvml.h`, já vem com o driver NVIDIA) para obter topologia PCIe e detetar NVLink — não assumir NVLink presente (no setup atual do utilizador, uma única RTX 3060, mas o código deve já estar preparado para o caso de vir a ter uma segunda GPU, mesmo que de outro modelo).
- Guardar a "distância" entre pares de GPUs (`nvmlDeviceGetTopologyCommonAncestor`) — isto informa o scheduler se comunicação GPU-GPU passa pelo mesmo switch PCIe ou tem de ir até à CPU, o que muda drasticamente a latência.

**Critério de aceitação:** um pequeno CLI (`umc_discover.exe`) que imprime a topologia detetada — nomes, VRAM total/livre, geração PCIe, largura de link. Correr e validar no setup atual (mesmo com 1 GPU só, para confirmar que o código não parte com pool de tamanho 1).

---

## 3. Extensão da Page Table para multi-GPU

```cpp
struct TensorPage {
    // ... campos existentes do UMC base ...
    MemoryTier current_tier;
    int        gpu_id = -1;   // válido apenas se current_tier == VRAM; -1 caso contrário
};
```

Regra de colocação (placement policy) no MVP: **afinidade estática por tensor**. Ou seja, ao carregar um modelo, o `GpuPoolManager` decide antecipadamente "os tensores 0-40 vão para a GPU 0, os tensores 41-80 para a GPU 1" (split por camadas, como um pipeline-parallel simples), em vez de tentar balanceamento dinâmico byte a byte — isto é muito mais simples de implementar corretamente e já resolve o caso de uso principal (modelo grande demais para 1 GPU).

Evoluir depois (não no MVP) para balanceamento dinâmico baseado em carga real, se fizer sentido.

---

## 4. Virtual GPU Context — a abstração que o PyTorch vê

```cpp
class VirtualGpuContext {
public:
    // Chamado pelo allocator (ver secção 5.1 do doc base)
    void* AllocateTensor(size_t size_bytes, uint64_t tensor_id);

    // Decide em qual GPU física colocar este tensor, com base em:
    // 1. VRAM livre em cada GPU do pool
    // 2. affinity policy (camadas consecutivas na mesma GPU sempre que possível)
    int ChooseGpuForTensor(uint64_t tensor_id, size_t size_bytes);

    // Executa um kernel, garantindo que os operandos estão todos na mesma GPU
    // antes de disparar — se não estiverem, dispara uma cópia P2P ou via RAM primeiro
    void EnsureCoLocated(std::vector<uint64_t> tensor_ids, int target_gpu);

private:
    GpuPoolManager pool_;
    PageTable*     page_table_;
};
```

Ponto crítico: **`EnsureCoLocated` é onde está o overhead real do multi-GPU.** Uma operação como uma multiplicação de matrizes precisa dos dois operandos na mesma GPU. Se estiverem em GPUs diferentes, há duas opções:

1. Cópia direta GPU→GPU via `cudaMemcpyPeerAsync` (só funciona bem se houver P2P access habilitado entre as GPUs — verificar com `cudaDeviceCanAccessPeer`; sem NVLink, isto ainda passa pelo PCIe e pela CPU em muitos casos).
2. Fallback: GPU origem → RAM pinned → GPU destino (mais lento, mas sempre funciona, incluindo entre GPUs de gerações/arquiteturas diferentes onde P2P pode não estar disponível).

**Implementar sempre a opção 2 como fallback obrigatório**, e só tentar a opção 1 como otimização quando `cudaDeviceCanAccessPeer` confirmar suporte.

---

## 5. Task Scheduler Multi-GPU

Para o MVP, **não** tentar dividir um único kernel CUDA a meio entre GPUs (isso é o domínio de frameworks como NCCL/Horovod, e é um projeto à parte, muito maior). Em vez disso:

- Adotar o modelo de **pipeline parallelism por camadas**, que é o que já se usa em `accelerate`/`device_map="auto"` do HuggingFace, mas aqui implementado ao nível do UMC para funcionar com qualquer runtime, não só transformers.
- Cada GPU processa as camadas que lhe foram atribuídas, passa a ativação para a próxima GPU (via `EnsureCoLocated`), e assim sucessivamente.
- Isto significa que o "Virtual GPU" visto pelo PyTorch não executa kernels ele próprio — só faz a gestão de memória e o scheduling de **onde** cada camada corre. A execução do kernel em si continua a ser feita pela GPU física normal via CUDA.

Isto simplifica brutalmente o projeto: não estás a reescrever cuBLAS/cuDNN para multi-GPU, estás só a decidir a topologia de onde os dados vivem e a mover ativações entre GPUs nos pontos de fronteira entre camadas.

**Critério de aceitação:** correr um modelo (ex: um LLM de ~13B em fp16, que não cabe numa RTX 3060 de 12GB) split em 2 "GPUs virtuais" — pode simular com 2 processos na mesma GPU física limitando VRAM artificialmente para o teste, já que o utilizador atualmente só tem 1 GPU — e validar que o forward pass completa corretamente, com output idêntico (dentro de tolerância numérica) ao mesmo modelo correndo numa única GPU maior (ou CPU, para comparação de correção).

---

## 6. Integração com PyTorch (extensão da secção 5.1 do doc base)

O `CUDAPluggableAllocator` já usado no UMC base continua a ser o ponto de entrada. A diferença é que agora `umc_alloc` consulta o `VirtualGpuContext::ChooseGpuForTensor` antes de decidir onde alocar:

```cpp
extern "C" void* umc_alloc(size_t size, int device, cudaStream_t stream) {
    // "device" aqui é o device lógico que o PyTorch pensa que existe (0)
    // internamente, o VirtualGpuContext decide o device físico real
    int physical_gpu = g_virtual_ctx.ChooseGpuForTensor(current_tensor_id, size);
    cudaSetDevice(physical_gpu);
    // ... alocação normal via pager UMC nesse device físico
}
```

Não é preciso um `torch.Device("umc_virtual")` custom para o MVP — o PyTorch continua a pensar que fala com `cuda:0`; o UMC é que decide por trás qual GPU física trata cada alocação. Isto poupa meses de trabalho de escrever um backend PyTorch inteiramente novo.

---

## 7. Plano de trabalho faseado (acrescenta-se ao doc base, depois da Fase 3)

### Fase 4 — GPU Pool Discovery (1 semana)
- Secção 2 completa. `umc_discover.exe` funcional.

### Fase 5 — Page Table multi-GPU + placement estático (1-2 semanas)
- Extensão de `TensorPage` com `gpu_id`.
- Afinidade estática por camada (secção 3).

### Fase 6 — EnsureCoLocated + fallback RAM (2 semanas)
- Implementar fallback via RAM pinned primeiro (mais simples, sempre funciona).
- Só depois otimizar com P2P se `cudaDeviceCanAccessPeer` for true no hardware de teste.

### Fase 7 — Validação end-to-end com modelo real (1-2 semanas)
- Critério de aceitação da secção 5 acima.

**Nota prática importante:** como o setup atual do utilizador só tem 1 GPU física (RTX 3060), as Fases 4-7 só podem ser testadas de verdade com uma segunda GPU no sistema, ou simulando "GPUs virtuais" como partições artificiais da mesma GPU (limitando VRAM por processo). Vale a pena decidir já qual dos dois caminhos de teste faz mais sentido antes de o coder começar a Fase 4, porque isso muda como o `GpuPoolManager` deve ser testado.

---

## 8. Riscos específicos desta camada (além dos já listados no doc base)

1. **Sem NVLink, o ganho de multi-GPU é limitado a casos onde o modelo simplesmente não cabe numa GPU** — não esperar speedup de throughput, só "passa a ser possível" em vez de "dá OOM".
2. **P2P entre GPUs de gerações diferentes** (ex: se no futuro juntar a RTX 3060 do desktop com outra GPU diferente) muitas vezes **não é suportado** — o fallback via RAM (secção 4, opção 2) tem de estar sempre pronto e testado, nunca assumir P2P disponível.
3. **Overhead de sincronização entre GPUs em pipeline parallelism** pode dominar o tempo total se as camadas forem pequenas — só vale a pena para modelos onde cada "bloco" de camadas atribuído a uma GPU tem trabalho computacional suficiente para amortizar o custo da transferência da ativação.
