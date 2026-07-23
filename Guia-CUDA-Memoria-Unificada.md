# Guia: Memória Unificada e Memória de Sistema em CUDA

Baseado no capítulo 2.6 do CUDA Programming Guide da NVIDIA (versão v13.3). Este guia explica os conceitos e, na secção final, liga-os diretamente ao que o teu projeto UMC está a tentar fazer.

## 1. O problema de base

Num sistema com CPU e uma ou mais GPUs, cada processador tem a sua própria memória física (DRAM) — a CPU tem RAM de sistema, cada GPU tem a sua VRAM. O desempenho é melhor quando os dados estão fisicamente na memória do processador que os está a usar. Gerir isto manualmente (decidir onde cada bloco de dados vive e copiá-lo explicitamente) funciona, mas é verboso e complica o design do software. O CUDA oferece um conjunto de funcionalidades para facilitar essa alocação, colocação e migração de dados entre memórias físicas diferentes — é isso que este capítulo cobre.

## 2. Espaço de endereçamento virtual unificado (UVA)

Toda a memória do sistema — RAM da CPU e VRAM de todas as GPUs — partilha um único espaço de endereçamento virtual dentro do mesmo processo. Isto aplica-se quer a memória alocada com APIs CUDA (`cudaMalloc`, `cudaMallocHost`) quer com APIs normais do sistema (`new`, `malloc`, `mmap`).

Na prática, isto significa:
- Dado um ponteiro qualquer, `cudaPointerGetAttributes()` diz-te onde é que essa memória realmente vive (CPU ou qual GPU).
- Podes usar `cudaMemcpyDefault` como tipo de cópia em `cudaMemcpy*()` e o CUDA deduz automaticamente a direção da cópia a partir dos próprios ponteiros, sem teres de especificar Host→Device, Device→Host, etc.

## 3. Memória unificada (managed memory)

*Memória unificada* é a funcionalidade que permite que alocações chamadas *managed memory* sejam acedidas tanto por código a correr na CPU como na GPU, sem cópias explícitas. Está disponível em todos os sistemas suportados por CUDA, mas a forma como se comporta varia consoante o sistema operativo, a versão do driver, e o hardware da GPU.

Há três formas de alocar managed memory explicitamente:
- API `cudaMallocManaged`
- `cudaMallocFromPoolAsync` com uma pool criada com `allocType = cudaMemAllocationTypeManaged`
- Variáveis globais com o especificador `__managed__`

Em sistemas com HMM ou ATS (explicados já a seguir), **toda** a memória do sistema é implicitamente managed memory, independentemente de como foi alocada — não precisas de alocação especial nenhuma.

### 3.1. Os quatro paradigmas de memória unificada

O comportamento exato depende de três atributos de dispositivo que se podem consultar com `cudaDeviceGetAttribute`:

| Atributo | Significado |
|---|---|
| `cudaDevAttrConcurrentManagedAccess` | 1 = suporte total; 0 = suporte limitado |
| `cudaDevAttrPageableMemoryAccess` | 1 = toda a memória do sistema é unificada; 0 = só a memória explicitamente alocada como managed |
| `cudaDevAttrPageableMemoryAccessUsesHostPageTables` | 1 = coerência por hardware; 0 = coerência por software |

Isto dá origem a quatro paradigmas:

1. **Suporte limitado** — `cudaDevAttrConcurrentManagedAccess = 0`. É o caso do **Windows** (incluindo WSL) e de alguns dispositivos Tegra.
2. **Suporte total só para alocações managed explícitas** — `cudaDevAttrPageableMemoryAccess = 0` e `ConcurrentManagedAccess = 1`.
3. **Suporte total com coerência por software (HMM)** — `PageableMemoryAccessUsesHostPageTables = 0`, os outros dois a 1. Linux com kernel 6.1.24 / 6.2.11 / 6.3+ e sem ATS.
4. **Suporte total com coerência por hardware (ATS)** — os três atributos a 1. Requer GPUs ligadas à CPU por NVLink Chip-to-Chip (C2C), como em Grace Hopper e Grace Blackwell — hardware de datacenter, não aplicável a um PC com GPU discreta ligada por PCIe.

### 3.2. O que "suporte total" (paradigmas 2–4) realmente significa

Quando há suporte total, o comportamento típico é:
- A managed memory é alocada, em geral, na memória do processador que a toca primeiro.
- É migrada automaticamente sempre que é usada por um processador diferente daquele onde reside atualmente.
- A migração acontece à granularidade de páginas de memória (coerência por software) ou linhas de cache (coerência por hardware).
- **É permitida oversubscription** — uma aplicação pode alocar mais managed memory do que a que existe fisicamente na GPU.

É este último ponto — oversubscription automática — que mais interessa ao teu projeto, e é exatamente onde o Windows fica de fora, como vês a seguir.

### 3.3. Suporte limitado — o caso do Windows

Este é o paradigma que se aplica ao teu ambiente (Windows 11). As regras são bem mais restritivas do que o suporte total:

- A managed memory é **sempre** alocada primeiro na memória física da CPU.
- A migração acontece a uma granularidade maior do que páginas de memória virtual.
- É migrada para a GPU **só quando a GPU começa a executar**.
- **A CPU não pode aceder à managed memory enquanto a GPU estiver ativa.**
- É migrada de volta para a CPU quando a GPU sincroniza.
- **Não é permitida oversubscription de memória da GPU.**
- Só a memória explicitamente alocada como managed pelo CUDA é unificada — memória de sistema normal (`malloc`, `new`) não é.

Este último conjunto de restrições — nenhuma oversubscription, sem acesso concorrente CPU/GPU — é a informação mais importante deste documento para o UMC.

## 4. Memória "page-locked" (pinned) e memória mapeada

### 4.1. Page-locked host memory

Memória alocada da forma tradicional (`malloc`, `new`, `mmap`) é "pageable" — o sistema operativo pode movê-la para disco ou realocá-la fisicamente a qualquer momento. Memória *page-locked* (também chamada *pinned*) fica fixa na RAM física e não pode ser trocada para disco.

- É obrigatória para cópias assíncronas CPU↔GPU.
- Melhora também o desempenho de cópias síncronas.
- Pode ser mapeada para a GPU, permitindo acesso direto a partir de kernels.

APIs relevantes:
- `cudaMallocHost` — aloca memória page-locked
- `cudaHostAlloc` — o mesmo, mas com flags para configurar outros parâmetros
- `cudaFreeHost` — liberta memória alocada pelas duas anteriores
- `cudaHostRegister` — torna page-locked uma alocação já existente, feita por `malloc`/`mmap`/outra biblioteca fora do controlo direto do CUDA

### 4.2. Memória mapeada (mapped memory)

Sem HMM ou ATS, tornar memória do host acessível à GPU requer *mapear* essa memória para o espaço de endereços da GPU. Memória mapeada é sempre page-locked.

Pontos importantes:
- Acesso a memória mapeada a partir de um kernel implica transações através da interligação CPU-GPU (PCIe ou NVLink), com latência mais alta e largura de banda mais baixa do que aceder à memória própria da GPU. **Não deve ser usada como alternativa de desempenho** à memória unificada ou à gestão explícita de memória para a maior parte das necessidades de um kernel.
- Com `cudaMallocHost`/`cudaHostAlloc`, a memória fica automaticamente mapeada e os ponteiros retornados podem ser usados diretamente em código de kernel.
- Com `cudaHostRegister`, ao contrário das duas anteriores, **não podes usar o ponteiro do host diretamente no kernel** — tens de obter um ponteiro específico do lado do dispositivo com `cudaHostGetDevicePointer()`.
- Também é conhecida por *zero-copy memory* em documentação mais antiga.

### 4.3. Memória unificada vs. memória mapeada — a diferença que importa

- Memória mapeada garante acesso, mas não garante que todos os tipos de operação (por exemplo, atómicas) sejam suportados em todos os sistemas. Memória unificada garante que todos os tipos de acesso são suportados.
- Memória mapeada permanece sempre em RAM da CPU — todo o acesso da GPU passa pela ligação PCIe/NVLink, nunca é "trazida para dentro" da GPU.
- Memória unificada é, em geral, migrada fisicamente para o processador que a está a aceder — depois da primeira migração, os acessos seguintes já usam a largura de banda total da memória da GPU.

## 5. Hints e prefetch

`cudaMemAdvise` deixa o programador dar pistas ao driver sobre onde uma alocação deve ficar colocada e se deve ou não ser migrada quando acedida por outro dispositivo. `cudaMemPrefetchAsync` permite pedir a migração assíncrona de uma alocação específica antes de ser necessária — por exemplo, começar a mover dados que um kernel vai usar antes desse kernel ser lançado, para a cópia acontecer em paralelo com outro trabalho da GPU.

## 6. Resumo oficial do capítulo

- Em Linux com HMM ou ATS, toda a memória alocada pelo sistema é managed memory.
- Em Linux sem HMM/ATS, em Tegra, e **em todo o Windows**, a managed memory tem de ser alocada explicitamente via CUDA (`cudaMallocManaged`, `cudaMallocFromPoolAsync` com o allocType certo, ou variáveis `__managed__`).
- No Windows e em Tegra, a memória unificada tem limitações (as listadas na secção 3.3).
- Só em sistemas ligados por NVLink C2C com ATS é que memória managed pode ser acedida diretamente pela CPU ou por outras GPUs sem migração.

---

## 7. O que isto significa concretamente para o UMC

Este documento confirma, com a fonte oficial da NVIDIA, uma coisa que já tinha sido identificada informalmente no projeto: **no Windows, a memória unificada nativa do CUDA não permite oversubscription.** É uma frase explícita do documento — no paradigma de suporte limitado, "oversubscription de memória da GPU não é permitida". Ou seja, mesmo que uses `cudaMallocManaged` da forma mais correta possível, o CUDA nativo no Windows **nunca** te vai deixar alocar mais managed memory do que a VRAM física disponível. A funcionalidade que resolveria o problema do UMC "de graça" simplesmente não existe na tua plataforma.

Isto tem três consequências diretas para o projeto:

1. **Confirma que a abordagem do `CUDAPluggableAllocator`, que já está no prompt do agente, é a correta — não uma alternativa de recurso.** Não é possível "ativar uma flag" e obter oversubscription automática no Windows; é preciso mesmo substituir o allocator do PyTorch por um próprio (o que a Fase 3 do prompt já pede) porque a funcionalidade equivalente do CUDA em si está bloqueada nesta plataforma.

2. **Explica também porque é que `cudaMallocManaged` nunca deve aparecer no código do UMC como solução de tiering.** Mesmo que o agente sugira em algum momento "porque não usamos `cudaMallocManaged` diretamente, é mais simples" — a resposta é que no Windows essa API tem as restrições da secção 3.3: aloca sempre primeiro em RAM, migra só quando a GPU começa a executar, a CPU fica proibida de aceder enquanto a GPU está ativa, e acima de tudo, não permite oversubscription. Nenhuma destas propriedades serve o objetivo do projeto.

3. **Os conceitos de "page-locked memory" e "memória mapeada" (secção 4) são exatamente o que já está implementado em `cleanup()` no `VirtualGpuMemory.cpp`.** As chamadas a `cudaHostUnregister` que já vimos no código correspondem ao par com `cudaHostRegister` descrito aqui — usado para tornar page-locked uma região de memória que foi alocada com `VirtualAlloc`/`mmap` fora do CUDA (que é exatamente o padrão que o UMC usa para gerir o tier de RAM). Vale a pena, quando o agente estiver a rever essa parte do código, confirmar que cada `cudaHostRegister` tem sempre um `cudaHostUnregister` correspondente antes de libertar a memória subjacente — este documento deixa claro que são operações emparelhadas, e esquecer o unregister antes do free é um erro comum nesta área.

Este ficheiro é boa referência para anexares ao `qwen3-coder-next` sempre que ele tiver de mexer na Fase 3 (o hook via `CUDAPluggableAllocator`) — dá-lhe o enquadramento oficial de porque essa é a única via viável no Windows, evitando que ele proponha "simplificações" que na prática não funcionam nesta plataforma.
