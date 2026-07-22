# App.py - Gerenciador de Memória Virtual

## Descrição
Implementação inicial do gerenciador de memória virtual (`app.py`) com suporte a:
- Alocação em VRAM (GPU) e RAM (CPU)
- Pinning CUDA para transferências rápidas
- Integração com TierManager via hooks
- Estatísticas de uso de memória

## Requisitos
- Python 3.10+
- PyTorch (versão compatível com CUDA se desejar usar VRAM)

## Uso Básico

```python
import app

# Inicializar capacidade virtual (VRAM + RAM em bytes)
app.initialize_virtual_capacity(
    vram=4*1024**3,  # 4 GB de VRAM
    ram=8*1024**3    # 8 GB de RAM
)

# Habilitar pinning CUDA (opcional, requer CUDA disponível)
app.enable_cuda_pinning(enabled=True)

# Alocar memória virtual
tensor = app.allocateSystemVirtual(size_bytes=1024)  # Aloca 1KB
print(f"Tensor alocado: {tensor.shape}, device={tensor.device}")

# Decidir tier e alocar (hook para TierManager)
tier_id, tensor = app.tier_manager_decide_tier_and_allocate(size_bytes=2048)
print(f"Tier escolhido: {tier_id} (0=VRAM, 1=RAM)")

# Ver estatísticas de memória
stats = app.get_memory_stats()
for k, v in stats.items():
    print(f"{k}: {v}")
```

## Funções Principais

### `initialize_virtual_capacity(vram: int, ram: int) -> None`
Inicializa a capacidade total de memória virtual.
- **vram**: Capacidade em bytes da VRAM disponível (0 se não houver GPU)
- **ram**: Capacidade em bytes da RAM disponível

### `allocateSystemVirtual(size_bytes: int, device_id: int = 0) -> torch.Tensor`
Aloca memória virtual.
- Retorna tensor alocado na GPU ou CPU dependendo do tier decidido
- Se pinning estiver habilitado e CUDA disponível, usa host-pinned memory

### `enable_cuda_pinning(enabled: bool = True) -> None`
Habilita/desabilita o uso de memória pinned CUDA.
- Apenas efetivo se PyTorch tiver suporte a CUDA

### `tier_manager_decide_tier_and_allocate(size_bytes: int, device_id: int = 0) -> Tuple[int, torch.Tensor]`
Hook para decisão do TierManager sobre onde alocar (VRAM ou RAM).
- Retorna `(tier_id, tensor)`
  - tier_id=0 → VRAM
  - tier_id=1 → RAM

### `get_memory_stats() -> dict`
Retorna estatísticas de memória:
```python
{
    'vram_used': int,
    'vram_total': int,
    'ram_used': int,  # Aproximado (sem psutil)
    'ram_total': int
}
```

## Integração com TierManager
O `app.py` fornece o hook `tier_manager_decide_tier_and_allocate()` para ser chamado pelo C++ via PyBind11 ou ctypes.

Exemplo de uso em C++ (pseudocódigo):
```cpp
// Via PyBind11
py::module app = py::import("app");
auto result = app.attr("tier_manager_decide_tier_and_allocate")(size_bytes, device_id);
int tier_id = result[0].cast<int>();
torch::Tensor tensor = result[1].cast<torch::Tensor>();
```

## Modo Fallback (Sem CUDA)
Se PyTorch não tiver suporte a CUDA:
- Todas as alocações ocorrem em CPU
- Aviso é exibido ao tentar habilitar pinning
- O código continua funcional para desenvolvimento e testes

## Testes
Execute os testes com:
```bash
python test_app.py
```

## Próximos Passos
1. Integrar com TierManager em C++
2. Adicionar suporte a alocação dinâmica de blocos
3. Implementar coleta de lixo (garbage collection) para memória virtual
4. Suporte a múltiplas GPUs via `device_id`