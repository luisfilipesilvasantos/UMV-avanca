
# UMC COM ARQUITETURA RAID-LIKE ADAPTADA À MEMÓRIA (FASE 2)

IMPLEMENTAR UMC COM ARQUITETURA RAID-LIKE ADAPTADA À MEMÓRIA

O objetivo é criar um sistema de Memória Unificada (UMC) que combina:
- Striping (RAID 0 adaptado)
- Paridade distribuída (RAID 5/6 adaptado)
- Tabela de índices lógica
- Controlador de memória unificada
- Reconstrução automática de blocos
- API pública para leitura/escrita
- Implementação dentro de DLLs do projeto

---

## 1. MEMORY STRIPING (RAID 0 ADAPTADO)
Implementar striping de memória para que vários módulos físicos apareçam como um único espaço contínuo.

Regras:
- Dividir a memória física em blocos fixos (ex: 4 KB, 8 KB, 16 KB).
- Distribuir blocos sequenciais entre todos os módulos de memória.
- O endereço lógico deve ser convertido em (módulo físico + offset).
- O espaço lógico deve ser contínuo e sem segmentação.

Exemplo:
Bloco 0 → Módulo 0
Bloco 1 → Módulo 1
Bloco 2 → Módulo 2
Bloco 3 → Módulo 0
Bloco 4 → Módulo 1
...

---

## 2. PARIDADE DISTRIBUÍDA (RAID 5/6 ADAPTADO)
Implementar paridade XOR para proteção sem duplicação.

Regras:
- Para cada grupo de N blocos, calcular um bloco de paridade:
P = B0 XOR B1 XOR B2 ... BN
- Guardar o bloco de paridade num módulo diferente do grupo.
- Permitir reconstrução de qualquer bloco perdido:
Bx = P XOR B0 XOR B1 XOR B2 (exceto Bx)

Paridade deve ser recalculada em cada escrita.

---

## 3. UNIFIED MEMORY INDEX TABLE (UMIT)
Criar uma tabela de índices que mapeia todo o espaço lógico.

Cada entrada deve conter:
- endereço lógico
- módulo físico
- offset físico
- bloco de paridade associado
- estado: válido / reconstruído / degradado

A UMIT deve ser atualizada em:
- cada escrita
- cada reconstrução
- cada realocação
- cada operação de paridade

A UMIT é essencial para manter o espaço unificado.

---

## 4. LOGICAL MEMORY CONTROLLER (LMC)
Criar um controlador que faz toda a lógica RAID-like.

Funções obrigatórias:
- Receber endereços lógicos
- Consultar a UMIT
- Ler/escrever no módulo correto
- Calcular paridade nas escritas
- Reconstruir blocos quando necessário
- Atualizar estados na UMIT
- Garantir coerência entre módulos

O LMC é a camada que transforma vários módulos físicos numa memória unificada.

---

## 5. API PÚBLICA DO UMC
A API deve expor apenas endereços lógicos.

Funções obrigatórias:

UMC_Read(address)
UMC_Write(address, data)
UMC_Rebuild(module_id)
UMC_GetStatus()
UMC_GetMap()

A aplicação UMC nunca deve aceder diretamente aos módulos físicos.

---

## 6. DLLS DO PROJETO
A DLL deve conter:
- LMC (Logical Memory Controller)
- UMIT (Unified Memory Index Table)
- Funções internas de striping
- Funções internas de paridade
- Funções internas de reconstrução

A DLL deve exportar:
- UMC_Read
- UMC_Write
- UMC_Rebuild
- UMC_GetStatus
- UMC_GetMap

A aplicação UMC deve usar apenas a DLL.

---

## 7. FLUXO DE LEITURA
1. Receber endereço lógico
2. Consultar UMIT
3. Determinar módulo físico + offset
4. Ler bloco
5. Se bloco estiver degradado:
- reconstruir usando paridade
6. Retornar dados

---

## 8. FLUXO DE ESCRITA
1. Receber endereço lógico + dados
2. Consultar UMIT
3. Determinar módulo físico + offset
4. Escrever bloco
5. Recalcular paridade
6. Atualizar UMIT
7. Confirmar operação

---

## 9. FLUXO DE RECONSTRUÇÃO
1. Identificar módulo falhado
2. Para cada bloco:
- ler blocos restantes
- ler paridade
- reconstruir bloco via XOR
3. Escrever bloco reconstruído no novo módulo
4. Atualizar UMIT
5. Marcar módulo como saudável

---

## 10. OBJETIVO FINAL
Criar um sistema de memória unificada que:
- soma todos os módulos (striping)
- protege contra falhas (paridade)
- mantém tudo contínuo (UMIT)
- reconstrói automaticamente (LMC)
- expõe API lógica (DLL)
- funciona como RAID adaptado à RAM

Este é o comportamento exato que deve ser implementado no UMC.
