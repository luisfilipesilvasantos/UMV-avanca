# Memória Unificada com Striping (RAID 0) + Paridade Distribuída
## Aplicação ao Unified Memory Controller (UMC) — Windows 11 + ComfyUI

---

## 1. Conceito Geral

A ideia é pegar dois princípios do mundo RAID e aplicá-los, por analogia, à gestão de memória heterogénea de um sistema com GPU:

- **Striping (estilo RAID 0):** dividir um bloco de dados grande (por exemplo, os pesos de um modelo carregado no ComfyUI) em fragmentos menores ("stripes") e distribuí-los simultaneamente por vários "discos" — neste caso, os três tiers de memória disponíveis: **VRAM**, **RAM do sistema** e **pagefile (SSD/NVMe)**.
- **Paridade distribuída (estilo RAID 5):** para cada conjunto de stripes, calcular um bloco adicional de paridade (tipicamente via XOR) e guardá-lo rotativamente por um dos tiers, permitindo reconstruir um stripe perdido ou corrompido sem ter de recarregar o dado inteiro a partir do disco original do modelo.

Note-se que RAID 0 puro não tem paridade — é o RAID 5 (ou RAID 4) que introduz esse conceito sobre striping. Aqui estamos a construir um **híbrido conceptual**: striping para desempenho (largura de banda agregada dos três tiers) + paridade para resiliência (tolerância a falhas de um tier sem perda total de contexto).

---

## 2. Porque faz sentido no contexto do UMC

O UMC já intercepta as alocações CUDA (via hooking do IAT / `CUDAPluggableAllocator`) para estender a VRAM efetiva usando RAM e pagefile como tiers de overflow. O problema atual é puramente **hierárquico**: quando a VRAM esgota, transborda para RAM; quando a RAM esgota, transborda para pagefile. Isto é sequencial e não tira partido da largura de banda agregada dos três tiers em simultâneo.

Aplicar striping resolve isso: em vez de "encher" um tier e só depois passar ao seguinte, um único tensor grande pode ser fragmentado e escrito/lido **em paralelo** nos três tiers, aproveitando os barramentos independentes (PCIe para VRAM, barramento de memória para RAM, controlador NVMe para pagefile).

A paridade resolve um problema secundário: se um stripe em pagefile corromper (por exemplo, devido a um erro de I/O no SSD) ou se o tier RAM for reclamado abruptamente pelo sistema operativo sob pressão de memória, o bloco pode ser reconstruído a partir dos restantes stripes + paridade, sem re-executar todo o carregamento do modelo a partir do disco.

---

## 3. Arquitetura Proposta

### 3.1 Unidade de stripe

- Definir um tamanho de stripe fixo (ex.: 4 MB ou 16 MB, alinhado com o tamanho de página do SO e com o tamanho ótimo de transferência PCIe).
- Cada tensor grande alocado pelo UMC é dividido em `N` stripes.

### 3.2 Distribuição (equivalente ao RAID 0)

- Os `N` stripes de dados são distribuídos ciclicamente pelos três tiers, com pesos proporcionais à largura de banda e latência de cada um:
  - **VRAM:** stripes mais "quentes" (acedidos frequentemente durante inferência) — prioridade máxima.
  - **RAM:** stripes "mornos" — segunda prioridade, boa latência.
  - **Pagefile/NVMe:** stripes "frios" — usados apenas como capacidade de reserva, maior latência.

### 3.3 Bloco de paridade (equivalente ao RAID 5)

- Para cada grupo de `N` stripes de dados, calcular um bloco de paridade `P = stripe1 XOR stripe2 XOR ... XOR stripeN`.
- O bloco de paridade é rotativo entre tiers (não fica sempre no mesmo tier, para evitar esse tier tornar-se um gargalo de escrita — o mesmo princípio do RAID 5 distribuído).
- Em caso de falha ou invalidação de um stripe (ex.: página descartada pelo SO), reconstrói-se: `stripeX = P XOR (stripes restantes)`.

### 3.4 Mapa de metadados

- Uma tabela de metadados (mantida em RAM, por ser pequena e crítica) associa:
  - ID do tensor → lista de stripes → localização física de cada stripe (tier + endereço) → localização do bloco de paridade correspondente.
- Este mapa é o equivalente ao "controlador RAID" em software.

---

## 4. Implementação em Windows 11

### 4.1 Alocação e movimentação de memória

- **VRAM:** continua a ser gerida via as chamadas CUDA interceptadas (`cudaMalloc`, `cudaMemcpy`) já existentes no UMC.
- **RAM:** usar `VirtualAlloc` com `MEM_COMMIT` e, idealmente, `VirtualLock` para os stripes "mornos" que não devem ser paginados pelo Windows (evita que o SO decida sozinho mover algo que o UMC já geriu para pagefile deliberadamente).
- **Pagefile:** em vez de depender do mecanismo de paging automático do Windows (que é opaco e não controlável ao nível do stripe), é preferível criar um **ficheiro de swap dedicado** gerido pela aplicação (ex.: via `CreateFile` com `FILE_FLAG_NO_BUFFERING` + `FILE_FLAG_OVERLAPPED` para I/O assíncrono direto), em vez de usar literalmente o pagefile do sistema. Isto dá controlo total sobre o layout dos stripes e evita competir com o resto do SO pelo pagefile partilhado.

### 4.2 Paralelismo de I/O

- Usar **I/O assíncrono sobreposto (Overlapped I/O)** ou a API **I/O Ring / IOCP** do Windows para disparar leituras/escritas de stripes em RAM e no ficheiro de swap dedicado em paralelo com as transferências CUDA (que já são assíncronas via streams).
- Sincronizar os três "braços" (VRAM/RAM/disco) com eventos ou um `ThreadPool` dedicado, de forma a que a leitura de um tensor completo aguarde apenas pelo stripe mais lento (latência dominada pelo pior caso, tipicamente o SSD).

### 4.3 Cálculo de paridade

- O XOR de paridade pode ser calculado em CPU (com instruções SIMD/AVX2 para velocidade) para stripes que envolvem RAM/pagefile, ou em GPU (kernel CUDA simples) quando um dos stripes está em VRAM, evitando cópias desnecessárias entre host e device.

---

## 5. Integração com o ComfyUI

- O ComfyUI carrega checkpoints, VAEs, LoRAs e modelos de texto-para-imagem/vídeo como grandes tensores. Estes são os candidatos naturais a serem geridos pelo UMC com striping:
  - **Pesos do modelo base (UNet/DiT):** maior parte do volume — beneficiam mais do striping, pois raramente cabem inteiramente em VRAM em GPUs de consumo.
  - **VAE e text encoders:** normalmente mais pequenos — podem ficar inteiramente em VRAM ou RAM, sem necessidade de striping.
  - **Latents intermédios durante a geração:** estes são acedidos com muita frequência (cada passo de sampling) — não são bons candidatos a striping com pagefile, pela latência; devem ficar em VRAM/RAM apenas.
- A camada de interceção do UMC (hook sobre `cudaMalloc`/alocador do PyTorch) decide, com base num limiar de "temperatura de acesso" (frequência de leitura/escrita), que tensores entram no esquema de striping+paridade e quais ficam fora dele (ex.: latents ativos do sampler nunca devem ser stripeados para disco).

---

## 6. Riscos e Limitações

- **Latência do pagefile/SSD:** mesmo com stripe dedicado, o NVMe é ordens de grandeza mais lento que VRAM/RAM. O striping ajuda no throughput agregado, mas não elimina o pior caso de latência — só é vantajoso para dados menos sensíveis à latência.
- **Overhead de paridade:** cada grupo de `N` stripes exige um stripe extra de paridade, aumentando o uso de espaço em ~1/N e o custo computacional do XOR. Para cargas de trabalho de inferência (leitura intensiva, escrita rara), a paridade só compensa se a probabilidade de falha/invalidação de stripes for real (ex.: sistema sob pressão de memória a descartar páginas).
- **Desgaste do SSD:** escrita frequente de stripes e paridade no ficheiro de swap dedicado aumenta o desgaste (wear) de SSDs, especialmente em unidades de consumo sem overprovisioning generoso.
- **Complexidade vs. ganho real:** para a maioria dos casos de uso do ComfyUI, o ganho de striping pode ser marginal se o gargalo real for a largura de banda do PCIe/NVMe em si, e não a falta de paralelismo. Vale a pena instrumentar e medir antes de assumir o ganho.

---

## 7. Plano de Fases Sugerido

1. **Fase 1 — Striping simples sem paridade:** implementar apenas a distribuição de stripes por VRAM/RAM/pagefile dedicado, com o mapa de metadados. Medir ganho de throughput agregado.
2. **Fase 2 — Paridade opcional:** adicionar o cálculo de paridade como funcionalidade configurável (ligar/desligar), aplicada apenas a stripes em RAM/disco (nunca aos latents ativos).
3. **Fase 3 — Heurística de temperatura de acesso:** classificar automaticamente que tensores entram no esquema, com base em padrões de acesso observados durante execução no ComfyUI.
4. **Fase 4 — I/O assíncrono otimizado:** migrar para IOCP/I/O Ring com pool de threads dedicado, sincronizado com CUDA streams.
5. **Fase 5 — Testes de resiliência:** simular falhas de stripe (corrupção induzida, descarte forçado de páginas) e validar reconstrução via paridade.
6. **Fase 6 — Benchmark comparativo:** comparar contra o comportamento atual do UMC (overflow sequencial hierárquico) em cenários reais de carga de modelos grandes no ComfyUI.

---

*Documento gerado como referência técnica para o projeto UMC (Unified Memory Controller).*
