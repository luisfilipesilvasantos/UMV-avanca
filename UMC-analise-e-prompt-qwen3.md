# UMC (Unified Memory Controller) — Análise e Prompt para o qwen3-coder-next

## 1. O que o projeto realmente é

O UMC tenta replicar, no Windows 11 com GPU(s) NVIDIA, o comportamento de "memória unificada" da Apple Silicon: quando um modelo (ComfyUI, Stable Diffusion, Ollama) não cabe em VRAM, os blocos menos usados são movidos para RAM (e depois pagefile), em vez de dar Out Of Memory. A ideia central — tiering de blocos VRAM→RAM→Pagefile com striping tipo RAID 0 entre GPUs, LRU eviction, working-set estimation, thrashing detection e prefetch — está implementada a sério em `VirtualGpuMemory.cpp` (~700 linhas). Não é um brinquedo: a lógica de gestão de memória existe e é razoavelmente sofisticada.

## 2. Estado real do projeto (o que encontrei ao abrir o zip)

**774 ficheiros, 90 MB, 98 scripts `.ps1`, 3 soluções Visual Studio diferentes (`Project.sln`, `UMC.sln`, `umc_project.sln`)** — sinais claros de várias sessões de IA a mexerem no mesmo diretório sem limpeza.

Pontos críticos:

1. **O mecanismo que dá nome ao projeto não existe.** `umc_injector.cpp` e `umc_hook.cpp` — os ficheiros que deveriam fazer o hook às chamadas CUDA do PyTorch — estão **vazios (0 bytes)**. Tudo o resto (tiering, RAID striping, eviction) funciona isolado num `.exe` de demonstração, mas nunca é injetado em nenhum processo real.

2. **Ficheiros duplicados e em conflito.** Existem pelo menos 6 versões diferentes do core (`VirtualGpuMemory.cpp`, `VirtualGpuMemory-Nemotron.cpp`, `virtualgpumemory_implementation.cpp`, `virtualgpumemory_implementatio.cpp` — com erro de escrita no nome —, `virtualgpumemory_implementation_patched.cpp`, `VirtualGpuMemory_backup.h`). O `compile_errors.txt` já incluído no zip confirma erros de "multiple definition" e "redefinition" quando estes ficheiros são compilados juntos — provavelmente resultado de pedir a diferentes modelos de IA para "corrigir" o mesmo ficheiro em sessões separadas.

3. **Dois sistemas de build paralelos e dessincronizados.** Há um `CMakeLists.txt` (assume MinGW/g++, é o que gerou o `compile_errors.txt`), e em paralelo `build_fixed.ps1` que usa `cl.exe` (MSVC) com um caminho fixo para `CUDA v13.3` — e ainda 3 ficheiros `.sln` do Visual Studio. Não há um caminho único e testado até ao fim.

4. **A ponte Python↔C++ não existe.** `app.py` (a "API" Python) é só uma simulação — aloca tensores PyTorch normais e não chama a DLL C++ em lado nenhum. O próprio `README.md` diz isto nos "Próximos Passos": *"Integrar com TierManager em C++"* ainda está por fazer.

5. **`requirements.txt` está desatualizado (torch 1.11.0 de 2022)**, incompatível com o ComfyUI Desktop atual, que corre em Python + PyTorch 2.x com CUDA 12.x.

6. **`run_comfyui_with_umc.ps1` não integra nada de facto.** Define variáveis de ambiente (`PYTORCH_CUDA_ALLOC_CONF`, `CUDA_MODULE_LOADING`) e depois lança `python main.py --highvram --gpu-only` num caminho fixo (`C:\Comfy-Desktop\Comfy Desktop`) que provavelmente nem corresponde à instalação real do ComfyUI Desktop (que é uma app Electron com Python embutido, não uma pasta com `main.py` solto). Hoje, este script **não liga a DLL UMC a nada** — é cosmética.

7. **Lixo não relacionado misturado na pasta**: o `winutil.ps1` (15 326 linhas — é o WinUtil do Chris Titus Tech), o instalador do Scoop (`install.ps1`), scripts de reset do Windows Update, limpeza do Edge, etc. Nada disto pertence ao UMC.

8. **Artefactos de build commitados no zip** (`x64/Debug`, `x64/Release`, `__pycache__`, ficheiros `.obj`) e uma dúzia de scripts `fix_*.py` / `clean-utf8-fix.ps1` que sugerem problemas repetidos de encoding (BOM/CRLF) em edições anteriores feitas por IA.

**Resumo em uma frase:** existe um motor de gestão de memória em C++ bem desenhado, mas isolado, nunca ligado ao PyTorch/ComfyUI, afogado em duplicados, dois sistemas de build a competir, e uma pasta cheia de ficheiros que não têm nada a ver com o projeto.

## 3. Prompt detalhado para o qwen3-coder-next

Copia o texto dentro da caixa abaixo (é tudo o prompt) e dá-o ao teu agente local. Está desenhado para ser executado por fases — não deixes o agente tentar fazer tudo de uma vez.

```
Vais trabalhar no projeto UMC (Unified Memory Controller), em C:\<caminho-do-projeto-UMC-avanca>.
É um sistema que estende a VRAM da(s) GPU(s) NVIDIA usando RAM de sistema e pagefile como tiers
de overflow, para correr modelos de IA (ComfyUI, Stable Diffusion) maiores do que a VRAM disponível,
substituindo o allocator de memória CUDA do PyTorch.

Trabalha por FASES, na ordem indicada. No fim de cada fase, para e apresenta um resumo do que mudou
antes de avançar para a fase seguinte. Não apagues nada permanentemente sem primeiro mover para uma
pasta /archive/ — quero poder recuperar se alguma coisa correr mal.

=== FASE 0 — Triagem e limpeza ===
1. Cria uma pasta /archive/unrelated-tools/ e move para lá tudo o que não pertence ao UMC:
   winutil.ps1, wmic.ps1, install.ps1 (o instalador do Scoop), Reset-WindowsUpdate.ps1,
   Reset-WindowsUpdate-GUI.ps1, EdgeDeepClean.ps1, "Disable Memory Compression.ps1", e qualquer
   outro script que não tenha relação direta com gestão de memória CUDA/UMC.
2. Apaga (não é preciso arquivar) as pastas de artefactos de build: x64/Debug, x64/Release,
   __pycache__, ZERO_CHECK.dir, umc_demo.dir, e ficheiros soltos *.obj. Cria um .gitignore
   a excluir estas pastas e extensões (*.obj, *.pdb, __pycache__/, x64/) para não voltarem a aparecer.
3. Lista todas as variantes duplicadas do core: VirtualGpuMemory.cpp, VirtualGpuMemory.h,
   VirtualGpuMemory-Nemotron.cpp, VirtualGpuMemory_backup.h, virtualgpumemory_header.cpp,
   virtualgpumemory_implementatio.cpp, virtualgpumemory_implementation.cpp,
   virtualgpumemory_implementation_patched.cpp. Faz diff entre elas e diz-me quais funcionalidades
   cada uma tem que as outras não têm (ex: writeBlockAsync, striping circular RAID0, working set
   estimation, thrashing detection). NÃO escolhas sozinho qual manter — apresenta-me o resumo do
   diff e espera a minha confirmação antes de consolidar num único VirtualGpuMemory.cpp +
   VirtualGpuMemory.h canónicos. As restantes vão para /archive/.
4. Consolida também os 3 ficheiros de solução Visual Studio (Project.sln, UMC.sln,
   umc_project.sln) e os vários .vcxproj num único projeto coerente, ou confirma comigo que
   vamos abandonar o Visual Studio a favor de um único CMakeLists.txt.

=== FASE 1 — Build limpo ===
1. Decide UM único toolchain e justifica a escolha: recomendo MSVC (Visual Studio 2022 Build
   Tools) + CUDA Toolkit, porque é o suportado oficialmente pela NVIDIA no Windows e é o que
   build_fixed.ps1 já pressupõe. Abandona a tentativa com MinGW/g++ que gerou compile_errors.txt.
2. Corrige build_fixed.ps1: em vez de ter o caminho do CUDA Toolkit fixo em
   "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3", deteta a versão instalada
   automaticamente (variável de ambiente CUDA_PATH ou procura em
   "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\") e falha com mensagem clara se não
   encontrar CUDA nem Visual Studio Build Tools instalados.
3. Corrige os erros já identificados em compile_errors.txt (redefinições de MemoryTier,
   BlockLocation, GpuDeviceInfo entre VirtualGpuMemory.h e cuda_runtime_mock.h; conversão
   wchar_t*/LPCSTR na linha ~162 de VirtualGpuMemory-Nemotron.cpp — nota: este ficheiro pode já
   ter sido arquivado na Fase 0, ajusta conforme o que sobreviver da consolidação).
4. Compila main.cpp + VirtualGpuMemory.cpp + UMCModelLoader.cpp num executável umc_demo.exe
   sem nenhum warning. Corre-o e confirma que os 7 testes que já existem em main.cpp passam
   (dummy model file, block layout dump, verificação de integridade, acesso byte-a-byte,
   working set estimation, thrashing detection, prefetch, page fault simulation).

=== FASE 2 — DLL + ponte Python ===
1. Usa o target "UMC" SHARED já definido no CMakeLists.txt para compilar VirtualGpuMemory.cpp +
   UMCModelLoader.cpp como UMC.dll.
2. Expõe uma API C simples com extern "C" __declspec(dllexport): umc_initialize(vram_bytes,
   ram_bytes, pagefile_bytes), umc_shutdown(), umc_get_stats() a devolver um struct/JSON com
   uso por tier, e as funções de alocação/libertação necessárias para o Passo 3.
3. Reescreve app.py: remove a simulação atual (que só cria tensores PyTorch normais e nunca toca
   na DLL) e liga-o de facto à UMC.dll via ctypes, chamando as funções expostas no ponto anterior.
   Atualiza também test_app.py para testar contra a DLL real, não contra a simulação.

=== FASE 3 — O hook real ao PyTorch (a parte mais delicada) ===
Não implementes isto por IAT hooking / DLL injection clássica — é frágil e já sabemos que o modo
expandable_segments:True do PyTorch contorna hooks de IAT por completo. Em vez disso:
1. Implementa um PyTorch CUDAPluggableAllocator (API oficial e suportada desde o PyTorch 2.x,
   ver torch.cuda.memory.CUDAPluggableAllocator): escreve duas funções C exportadas com a
   assinatura exigida — void* umc_alloc(size_t size, int device, cudaStream_t stream) e
   void umc_free(void* ptr, size_t size, int device, cudaStream_t stream) — que por dentro chamam
   a lógica de tiering já existente em VirtualGpuMemory para decidir se o bloco fica em VRAM ou
   se é redirecionado para RAM/pagefile.
2. Compila isto como um DLL separado (umc_pluggable_allocator.dll) exportado do mesmo projeto.
3. No lado Python, cria um pequeno módulo umc_bootstrap.py que faz:
   torch.cuda.memory.CUDAPluggableAllocator("umc_pluggable_allocator.dll", "umc_alloc", "umc_free")
   seguido de torch.cuda.memory.change_current_allocator(...). Este bootstrap tem de correr
   ANTES de qualquer chamada CUDA do PyTorch (antes de "import torch" fazer qualquer alocação),
   caso contrário o allocator não pode ser trocado.
4. Deixa os ficheiros umc_injector.cpp e umc_hook.cpp vazios como estão, ou apaga-os e documenta
   no README porque a abordagem de injection foi substituída pelo CUDAPluggableAllocator.

=== FASE 4 — Integração com ComfyUI Desktop ===
1. O ComfyUI Desktop é uma app Electron com Python embutido — NÃO assumas o caminho
   "C:\Comfy-Desktop\Comfy Desktop" que está hardcoded em run_comfyui_with_umc.ps1. Deteta o
   caminho de instalação real (normalmente em %LOCALAPPDATA%\Programs\comfyui-electron ou
   pergunta-me o caminho na primeira execução e guarda-o num ficheiro de config local).
2. Atualiza requirements.txt para a versão de PyTorch que o ComfyUI Desktop realmente usa
   (verifica o ambiente Python embutido da instalação, tipicamente torch 2.x + cu12x) em vez do
   torch==1.11.0 atual, que é de 2022 e incompatível.
3. Reescreve run_comfyui_with_umc.ps1 para: (a) detetar/pedir o caminho do ComfyUI Desktop,
   (b) verificar que umc_pluggable_allocator.dll e UMC.dll existem e estão compiladas,
   (c) injetar o import de umc_bootstrap.py ANTES do arranque do main.py do ComfyUI (por exemplo
   via variável de ambiente PYTHONSTARTUP, ou um wrapper que faz "import umc_bootstrap" antes de
   invocar o entrypoint do ComfyUI), (d) só depois lançar o ComfyUI Desktop.

=== FASE 5 — Testes, do mais simples ao mais arriscado ===
1. Testa primeiro umc_demo.exe isolado (Fase 1).
2. Depois testa um script Python mínimo, fora do ComfyUI, que força uma alocação CUDA maior do
   que a VRAM disponível e confirma que não dá Out Of Memory, mas também confirma a velocidade —
   compara com uma alocação normal para veres o overhead real do tiering.
3. Só depois de 1 e 2 passarem, testa dentro do ComfyUI Desktop com um checkpoint pequeno,
   e só depois com um checkpoint que sabemos que excede a VRAM.
4. Em qualquer fase, se o sistema (não só o ComfyUI) ficar instável, reporta imediatamente e
   não avances — isto está a mexer no allocator de memória CUDA de um processo real.

=== FASE 6 — Documentação final ===
Substitui o README.md atual por um único documento com: arquitetura real (não a aspiracional),
como compilar, como correr os testes da Fase 5, como ligar ao ComfyUI Desktop, e limitações
conhecidas. Apaga ou arquiva os documentos redundantes (UMC Integration Guide.md,
UMC_RAID_SPEC.md, memoria-unificada-raid-parity.md, UMC_Projeto_Memoria_Unificada*.txt) depois
de confirmares comigo que o conteúdo relevante de cada um já está capturado no novo README.

Regras gerais para todas as fases:
- Comenta o código em português, como o resto do projeto já está.
- Não avances de fase sem eu confirmar.
- Se encontrares mais ficheiros duplicados ou conflituosos que eu não listei, para e pergunta
  antes de decidir sozinho qual manter.
```

## 4. Tutorial de uso

### 4.1 Preparar o terreno
1. Confirma que tens instalados: **Visual Studio 2022 Build Tools** (workload "Desktop development with C++") e o **CUDA Toolkit** da NVIDIA (a versão correspondente ao driver da tua GPU). Sem isto o agente não consegue sequer compilar a Fase 1.
2. Extrai o zip para uma pasta de trabalho limpa, fora de qualquer pasta OneDrive/sincronizada (para evitar bloqueios de ficheiros durante a compilação).

### 4.2 Dar o prompt ao qwen3-coder-next
- Se usares o teu `coder_agent.py` (o agente PyQt5/ReAct que já tens sobre Ollama), aponta-o para a pasta extraída do projeto e cola o prompt da secção 3 como primeira instrução.
- Se preferires correr o `qwen3-coder-next` diretamente via Ollama, faz `ollama run qwen3-coder-next` numa consola aberta *dentro* da pasta do projeto (para que o modelo tenha o caminho relativo correto), e cola o mesmo prompt.
- O prompt já instrui o modelo a parar no fim de cada fase — respeita isso. Não digas "faz tudo de seguida", especialmente na Fase 0 (consolidação de duplicados) e na Fase 3 (o hook ao CUDA), onde uma decisão errada pode ser difícil de desfazer.

### 4.3 Acompanhar a Fase 0 e 1
- Confirma manualmente o diff que o agente apresentar entre as versões duplicadas do `VirtualGpuMemory.cpp` antes de autorizar a consolidação — é o ficheiro mais importante do projeto.
- No fim da Fase 1 deves ter um `umc_demo.exe` que corre sem erros e imprime os 7 testes de demonstração já existentes em `main.cpp`.

### 4.4 Testar antes de tocar no ComfyUI
- Não saltes a Fase 5.2 (teste isolado em Python fora do ComfyUI). É a única forma de confirmares que o `CUDAPluggableAllocator` está mesmo a redirecionar alocações para RAM sem crashar, antes de arriscares a instabilidade dentro de uma aplicação com interface gráfica.
- Faz um ponto de restauro do Windows ou um snapshot antes dos primeiros testes da Fase 3/5 — estás a substituir o allocator de memória CUDA de um processo real, e um bug aqui pode ir desde um crash simples até instabilidade do driver da GPU.

### 4.5 Ligar ao ComfyUI Desktop
- Deixa o agente detetar o caminho de instalação real do ComfyUI Desktop em vez de assumir `C:\Comfy-Desktop\Comfy Desktop` — esse caminho estava errado no script original.
- Testa primeiro com um checkpoint pequeno (que já cabe em VRAM normalmente) para confirmar que o ComfyUI arranca sem regressões, e só depois com um modelo que sabes que excede a tua VRAM.

### 4.6 Sinais de alarme a que deves prestar atenção
- Se o `umc_demo.exe` da Fase 1 não passar nos 7 testes internos, não avances para a Fase 2.
- Se o teste isolado da Fase 5.2 for muito mais lento do que uma alocação CUDA normal (overhead grande), o ganho de "correr modelos maiores" pode não compensar na prática — vale a pena perguntares ao agente para reportar os números antes de integrar no ComfyUI.
- Qualquer crash do sistema (não só do ComfyUI) durante os testes da Fase 3 em diante é motivo para parar e rever a implementação do `CUDAPluggableAllocator`, não para tentar "forçar" com mais patches.
