# Guia Técnico para Desenvolvedores: Recursos NVIDIA vGPU com Foco em Memória Unificada (UVM)

**Data de Referência:** Julho de 2026  
**Público-Alvo:** Engenheiros de Software, Desenvolvedores CUDA/C++ e Arquitetos de Sistemas  
**Objetivo:** Fornecer o conhecimento técnico necessário sobre a infraestrutura NVIDIA vGPU para o desenvolvimento e otimização de projetos baseados em **Unified Virtual Memory (UVM)**.

---

## 1. Foco Principal: Unified Virtual Memory (UVM)

A **Unified Virtual Memory (UVM)** fornece um único espaço de endereçamento de memória acessível tanto pelas CPUs como pelas GPUs do sistema. Cria um pool de memória gerido que permite que os dados sejam alocados e acedidos por código em execução em qualquer CPU ou GPU.

### 1.1. Impacto no Desenvolvimento (O que muda no código?)
* **Eliminação de Transferências Manuais:** A UVM elimina a necessidade de os programadores escreverem código para transferências explícitas de dados entre a memória da CPU e da GPU (ex: `cudaMemcpy`). O sistema gere as migrações de páginas automaticamente.
* **Simplificação da Programação:** Permite escrever código como se toda a memória fosse unificada, facilitando a integração de workloads acelerados por GPU.
* **Casos de Uso Ideais:** Machine Learning, análise de dados, simulações científicas, simulações em tempo real e fluxos de trabalho intensivos em dados (especialmente em Linux).

### 1.2. ⚠️ Restrições e Limitações Críticas (Atenção ao Design da Arquitetura)
Como desenvolvedor, **deves ter em conta as seguintes limitações** ao desenhar a tua aplicação para UVM:

1. **Incompatibilidade com Live Migration:** Habilitar a UVM **desativa a migração ao vivo (vGPU migration)** para a VM. Se o teu projeto requer alta disponibilidade e migração transparente entre hosts, a UVM não pode ser usada.
2. **Limitação de Sistema Operativo e Perfil:** A UVM manual é suportada **apenas em sistemas operativos Linux** e é limitada a perfis **vGPU da série Q** ou perfis **da série C** (empacotados com NVIDIA AI Enterprise) que alocam o frame buffer inteiro de uma GPU física compatível.
3. **Incompatibilidade com vGPU Fracionado:** vGPUs com *time-slicing* fracionado (fractional time-sliced) **não são compatíveis** com UVM.
4. **Limitações de Profiling (CUDA Toolkit):**
   * Os profilers (Nsight Compute, Nsight Systems, CUPTI) só podem ser usados em **uma VM de cada vez por GPU física**.
   * Profilar múltiplos contextos CUDA simultaneamente não é suportado.
   * **Uma VM com profilers CUDA ativados não pode ser migrada.**
   * *Nota:* Ao usar Nsight Compute ou CUPTI, os relógios (clocks) são bloqueados automaticamente para profiling multipass. Deves monitorizar o impacto deste bloqueio em ambientes partilhados.

### 1.3. Configuração e Habilitação
* **Estado Padrão:** A UVM é **desativada por padrão** e deve ser explicitamente habilitada para cada vGPU que a necessite.
* **Como Habilitar:** Define um parâmetro do plugin vGPU para a VM (`vGPU plugin parameter`).
* **Exceção (Windows/Azure):** A UVM vem **habilitada por padrão** no *Microsoft Azure Local* e *Microsoft Windows Server*. Se não a quiseres usar nestes ambientes, tens de a desativar manualmente através do parâmetro do plugin.

---

## 2. Arquitetura de Memória e Particionamento de Hardware

Para além da UVM, o teu projeto pode beneficiar (ou ser restringido) por outras formas como a memória da GPU é particionada e alocada no hypervisor.

### 2.1. Multi-Instance GPU (MIG) e Universal MIG
O MIG permite o particionamento espacial de um único chip GPU físico em múltiplas instâncias isoladas. Cada instância funciona como uma "mini-GPU" dedicada com os seus próprios **Streaming Multiprocessors (SMs) e subsistema de memória**.
* **Isolamento de Memória:** Garante isolamento ao nível de hardware, eliminando a contenção de recursos e garantindo desempenho previsível.
* **Universal MIG (Gráficos + Compute):** As GPUs *RTX PRO 6000 Blackwell* e *RTX PRO 4500 Blackwell Server Edition* suportam Universal MIG, permitindo workloads de gráficos e compute na mesma partição MIG (anteriormente limitado apenas a compute).
* **Capacidade de Memória/VMs:**
  * *RTX PRO 6000 Blackwell:* Até 4 fatias MIG. Até 12 vGPUs por fatia (Total: 48 VMs por GPU).
  * *RTX PRO 4500 Blackwell:* Até 2 fatias MIG. Até 8 vGPUs por fatia (Total: 16 VMs por GPU).
* **MIG-Backed vGPU:** Combina o isolamento espacial do MIG com o particionamento temporal do vGPU.

### 2.2. Multi-vGPU (Agregação de Memória)
Permite que uma única VM utilize múltiplas vGPUs simultaneamente.
* **Agregação de Frame Buffer:** Podes atribuir até 16 vGPUs a uma única VM (desde que sejam do mesmo tipo e série, ex: L40S-24Q com L40S-16Q).
* **Casos de Uso:** Modelos de IA em larga escala que exigem mais memória VRAM do que uma única GPU física possui, ou renderização fotorealista.

### 2.3. Heterogeneous vGPU (Particionamento Flexível)
Permite que uma única GPU física suporte múltiplos perfis vGPU com alocações de memória (frame buffer) diferentes simultaneamente.
* **Exemplo Prático:** Uma GPU L40S de 48GB pode ter uma VM com L40S-8Q (para renderização 3D) e outra com L40S-2B (para tarefas leves de escritório).
* **Atenção ao Desenvolvedor (Overhead de Alinhamento):** Devido a restrições de empacotamento e alinhamento, a memória total utilizável pode ser menor. *Exemplo:* Uma L40S de 48GB suporta 6 instâncias de L40S-8Q no modo "Equal-Size", mas apenas **4 instâncias** no modo "Heterogeneous".

---

## 3. Gestão de Estado da Memória (Mobilidade da VM)

Se a tua aplicação armazena estado crítico na memória da GPU, deves considerar como o hypervisor lida com a mobilidade da VM.

### 3.1. Suspend-Resume (Suspensão e Retoma)
* **Como funciona:** O estado da VM (incluindo o frame buffer da vGPU e estado de execução) é guardado em disco.
* **Impacto na Memória:** Liberta a memória da GPU e recursos de compute enquanto suspensa.
* **Requisito de Performance:** Como o estado da memória é escrito em disco, **deves usar discos de alta performance (SSDs)** para evitar que os tempos de suspensão/retoma sejam inaceitáveis.
* **Compatibilidade:** Suporta migração entre hosts, mas exige que o host de destino tenha o mesmo tipo de GPU física, topologia NVLink idêntica e configuração de memória (ECC) igual.

### 3.2. Live Migration (Migração ao Vivo)
* **Como funciona:** Replica a memória do sistema, estado da CPU, frame buffer e estado de execução da vGPU em tempo real para o host de destino.
* **Restrição Crítica para UVM:** Como mencionado na secção 1, **a UVM desativa a Live Migration**. Se o teu projeto de Memória Unificada exigir alta disponibilidade, terás de contornar isto ao nível da aplicação (ex: guardando estado em memória de CPU ou storage externo) em vez de depender da migração da VM.
* **Incompatibilidades:** Não suporta VMs que usem *Unified memory*, *Debuggers* ou *Profilers* do CUDA Toolkit.

---

## 4. Agendadores de GPU (vGPU Schedulers)

O agendador determina como o tempo de GPU e o acesso à memória são partilhados. A escolha do agendador afeta a latência e o throughput da tua aplicação.

| Modo | Comportamento | Quando usar no teu projeto |
| :--- | :--- | :--- |
| **Best Effort** | Aloca recursos com base na procura atual (Round Robin). Se uma VM está inativa, outra usa o tempo. | Workloads flutuantes, maximização de densidade de utilizadores. (Padrão). |
| **Equal Share** | Divide os ciclos da GPU igualmente (1/N) entre todas as vGPUs ativas. O tempo inativo de uma VM não é reutilizado por outras. | Ambientes que exigem justiça estrita e consistência, onde o throughput médio é mais importante que a latência de pico. |
| **Fixed Share** | Aloca uma porção fixa e dedicada (ex: 25% para cada uma de 4 VMs). O desempenho não flutua com a carga de outras VMs. | **Ideal para benchmarks, POCs e aplicações de alta prioridade** que exigem desempenho previsível e estável na memória/compute. |

*Nota:* O *Frame-Rate Limiter (FRL)* é desativado automaticamente ao usar *Equal Share* ou *Fixed Share*.

---

## 5. Recursos Adicionais Relevantes

### 5.1. Device Groups (Grupos de Dispositivos)
* **Conceito:** Abstração que agrupa dispositivos fisicamente conectados (ex: GPUs ligadas via NVLink ou pares GPU-NIC no mesmo switch PCIe) numa única unidade lógica.
* **Importância para Compute/IA:** Garante que a tua VM receba o conjunto completo de hardware com comunicação de baixa latência e alta largura de banda. Essencial se o teu projeto de memória unificada exigir transferência massiva de dados entre múltiplas GPUs (NVLink).
* **Suporte:** Introduzido no VMware vSphere 8. Integrado com o DRS para placement correto da VM.

### 5.2. Deep Learning Super Sampling (DLSS)
* **Conceito:** Tecnologia de upscaling baseada em IA (Tensor Cores) que reconstrói frames de alta resolução a partir de inputs de baixa resolução.
* **Relevância:** Se o teu projeto envolver visualização 3D, CAD ou renderização em estações de trabalho virtuais (RTX vWS), o DLSS reduz a carga na memória e no pipeline de renderização, melhorando drasticamente os FPS.
* **Suporte:** Requer GPUs da série Ada/L40/L4/L2/A-series/T4 e versão DLSS 2.0.

---

## 6. Resumo e Próximos Passos para o Desenvolvedor

1. **Validar o Sistema Operativo e Hypervisor:** Confirma se o teu ambiente alvo (Linux KVM, VMware, etc.) suporta os perfis Q-series ou C-series necessários para a UVM.
2. **Decisão de Arquitetura (UVM vs. Live Migration):** Toma a decisão consciente de que ao usar UVM, perdes a capacidade de Live Migration da VM. Desenha a tua aplicação para ser *stateless* ao nível da VM, ou gere o estado externamente.
3. **Configuração de Ambiente:** Prepara os scripts de automação (Terraform, Ansible, ou scripts do Hypervisor) para injetar o `vGPU plugin parameter` que habilita a UVM nas VMs Linux.
4. **Estratégia de Profiling:** Planeia as sessões de debugging com Nsight/CUPTI. Lembra-te que só podes profilear uma VM de cada vez por GPU física e que isso também bloqueia a migração.
5. **Avaliar MIG vs. Time-Slicing:** Se a tua aplicação de Memória Unificada for multi-tenant e exigir isolamento rigoroso de memória e compute, avalia a migração para hardware Blackwell (RTX PRO 6000/4500) para tirar partido do *Universal MIG*.