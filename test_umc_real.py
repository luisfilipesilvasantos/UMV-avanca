#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Teste real da DLL UMC com PyTorch (versão Release)
Verifica se a DLL funciona com CUDA REAL (nunca mock)
"""

import torch
import ctypes
from pathlib import Path
import sys

print("=" * 60)
print("TESTE INTEGRACAO UMC COM PYTORCH - RELEASE (CUDA REAL)")
print("=" * 60)

# Verificar CUDA
cuda_available = torch.cuda.is_available() if hasattr(torch, 'cuda') else False
print(f"\nCUDA Disponível: {cuda_available}")

if cuda_available:
    print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.device_count() > 0 else 'N/A'}")
    print(f"VRAM Total: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

# Carregar DLL UMC
umc_dll_path = Path("C:/Users/luisf/UMC-avanca/x64/Release/umc.dll")
if not umc_dll_path.exists():
    print(f"\nERRO: DLL UMC não encontrada em {umc_dll_path}")
    sys.exit(1)

print(f"\nDLL UMC carregada de: {umc_dll_path}")

try:
    umc = ctypes.CDLL(str(umc_dll_path))
    print("OK: DLL UMC carregada")
except Exception as e:
    print(f"ERRO ao carregar DLL UMC: {e}")
    sys.exit(1)

# Testar funções exportadas
expected_exports = ['UMC_Init', 'UMC_Destroy', 'umc_alloc', 'umc_free', 'umc_init_allocator']
print("\nVerificar símbolos exportados:")
for sym in expected_exports:
    try:
        func = getattr(umc, sym)
        print(f"  OK: {sym}")
    except AttributeError:
        print(f"  ERRO: {sym} NÃO EXPORTADO")
        sys.exit(1)

# Testar umc_init_allocator
print("\nTestar umc_init_allocator:")
try:
    umc.umc_init_allocator.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
    umc.umc_init_allocator.restype = None
    
    # Inicializar com 8GB VRAM e 16GB RAM (valores realistas)
    umc.umc_init_allocator(8 * 1024**3, 16 * 1024**3)
    print("OK: umc_init_allocator chamada com sucesso")
except Exception as e:
    print(f"ERRO ao chamar umc_init_allocator: {e}")
    sys.exit(1)

# Testar PyTorch com allocator personalizado
print("\n" + "-" * 60)
print("TESTE PYTORCH ALLOCATOR")
print("-" * 60)

if not cuda_available:
    print("CUDA não disponível, não é possível testar alocador CUDA")
    sys.exit(0)

try:
    # Criar tensor na GPU usando allocator padrão
    x = torch.randn(10, 10, device='cuda:0')
    print(f"OK: Tensor criado em GPU (CUDA real): shape={x.shape}")
    
    # Agora tentar usar o alocador customizado via CUDAPluggableAllocator
    from torch.cuda.memory import CUDAPluggableAllocator
    
    allocator = CUDAPluggableAllocator(str(umc_dll_path), 'umc_alloc', 'umc_free')
    torch.cuda.memory.change_current_allocator(allocator)
    
    print("OK: CUDAPluggableAllocator configurado")
    
    # Criar tensor usando o alocador customizado
    y = torch.randn(5, 5, device='cuda:0')
    print(f"OK: Tensor alocado com allocator customizado: shape={y.shape}")
    
    # Verificar que funciona operações GPU
    z = x + y
    print(f"OK: Operação GPU realizada (x + y): shape={z.shape}")
    
except Exception as e:
    print(f"\nERRO no teste do allocator: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n" + "=" * 60)
print("TESTE CONCLUÍDO COM SUCESSO!")
print("=" * 60)
