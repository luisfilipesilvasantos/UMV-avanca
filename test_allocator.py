import torch
from torch.cuda.memory import CUDAPluggableAllocator, change_current_allocator
import os
torch.cuda.memory.change_current_allocator(CUDAPluggableAllocator(os.path.abspath("allocator.dll"), "my_alloc", "my_free"))
print(torch.empty(1000, device='cuda'))