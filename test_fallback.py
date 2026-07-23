import torch
from torch.cuda.memory import CUDAPluggableAllocator
import os

torch.cuda.memory.change_current_allocator(
    CUDAPluggableAllocator(os.path.abspath("allocator.dll"), "my_alloc", "my_free")
)

# força um pedido maior do que a VRAM da placa (12GB) para disparar o fallback
big_tensor = torch.empty(100 * 1024**3 // 4, dtype=torch.float32, device='cuda')
print("Alocação grande OK:", big_tensor.shape, big_tensor.device)
