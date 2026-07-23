# Guia de Sobrevivência ao OOM (Out-of-Memory) em Python: Estratégias para Dados e Modelos Gigantes

**Data de Referência:** Julho de 2026  
**Público-Alvo:** Desenvolvedores que já viram o temido `CUDA Out of Memory` ou `MemoryError` e querem dominar a Memória Unificada (RAM + Page File + VRAM).  
**Objetivo:** Traduzir as 4 estratégias clássicas de gestão de dados em memória para o carregamento e inferência de **modelos de IA de grande porte**, com a lista exata de pacotes PyPI para auditar o teu ambiente.

---

## 1. As 4 Estratégias Fundamentais (Adaptadas para Modelos Carregados)

O documento original foca-se em *datasets*, mas a arquitetura de resolução é **exatamente a mesma** para carregar modelos que não cabem na memória. Aqui está a tradução para o teu projeto:

### 1.1. Chunking (Processamento em Blocos)
- **Conceito Original:** Ler um CSV gigante em pedaços (ex: 30.000 linhas de cada vez) em vez de carregar tudo de uma vez.
- **Aplicação em Modelos:** Em vez de carregar o ficheiro de pesos do modelo (`.bin` ou `.safetensors`) inteiro na RAM, usamos bibliotecas que carregam o modelo **camada por camada** (layer-wise loading) ou usam *sharded checkpoints* (vários ficheiros pequenos).
- **Vantagem:** Controlo total sobre o pico de memória. O sistema nunca aloca o modelo inteiro de uma só vez.

### 1.2. Lazy Computation (Avaliação Preguiçosa) e Memory Mapping (`mmap`)
- **Conceito Original:** Bibliotecas como Dask ou Polars não executam a operação imediatamente; elas criam um "plano de execução" e só processam os dados quando absolutamente necessário (`.collect()`).
- **Aplicação em Modelos:** Usar formatos de modelo que suportam **Memory Mapping (`mmap`)**. O sistema operativo mapeia o ficheiro do modelo no disco diretamente para o espaço de endereçamento virtual, carregando na RAM física *apenas* as páginas de memória (pesos) que estão a ser ativamente usadas pela GPU/CPU naquele milissegundo. O resto fica no disco (Page File), à espera.

### 1.3. Disk-Backed Storage (Armazenamento Suportado em Disco)
- **Conceito Original:** Carregar dados em blocos para uma base de dados SQLite no disco e fazer queries SQL apenas aos subconjuntos necessários, sem passar pela RAM.
- **Aplicação em Modelos:** Configurar um `offload_folder` (pasta de descarregamento) num SSD NVMe rápido. Quando a RAM enche, o framework move ativamente os tensores inativos do modelo para o disco, libertando a RAM para as camadas que estão a ser processadas. É o "Page File sob controlo programático".

### 1.4. Parallel & Distributed Processing (Processamento Paralelo)
- **Conceito Original:** Usar Dask para distribuir o cálculo por vários núcleos ou máquinas, evitando o gargalo de uma única máquina.
- **Aplicação em Modelos:** Usar bibliotecas como `DeepSpeed` (ZeRO-Offload) ou `accelerate` para dividir o estado do modelo, otimizador e gradientes entre a GPU, a CPU (RAM) e o Disco (NVMe) de forma coordenada.

---

## 2. O Arsenal PyPI: O que verificar com `pip list`

Para implementar estas estratégias, o teu ambiente Python precisa destas armas. Executa o comando abaixo para auditar o teu sistema.

**Comando de Auditoria (Windows PowerShell):**
```powershell
pip list | Select-String -Pattern "pandas|dask|polars|accelerate|safetensors|llama-cpp-python|deepspeed|h5py|zarr"