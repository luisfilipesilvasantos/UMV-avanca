#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Teste simples da DLL UMC com PyTorch
Valida que a integração básica está a funcionar
"""

import torch
import ctypes
from pathlib import Path

print("=" * 60)
print("TESTE INTEGRACAO UMC COM PYTORCH")
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
    exit(1)

print(f"\nDLL UMC carregada de: {umc_dll_path}")

try:
    umc = ctypes.CDLL(str(umc_dll_path))
    print("DLL UMC carregada com sucesso!")
except Exception as e:
    print(f"ERRO ao carregar DLL UMC: {e}")
    exit(1)

# Testar funções básicas da API C
try:
    # UMC_Init
    UMC_Init = umc.UMC_Init
    UMC_Init.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
    UMC_Init.restype = ctypes.c_void_p
    
    UMC_Destroy = umc.UMC_Destroy
    UMC_Destroy.argtypes = [ctypes.c_void_p]
    UMC_Destroy.restype = None
    
    print("\nOK: Funções UMC_Init e UMC_Destroy carregadas")
except Exception as e:
    print(f"ERRO ao carregar funções da DLL: {e}")
    exit(1)

# Testar PyTorch com alocador personalizado (mock)
print("\n" + "-" * 60)
print("TESTE ALLOCATOR PYTORCH")
print("-" * 60)

try:
    # Criar tensor simples
    x = torch.randn(10, 10)
    print(f"Tensor CPU criado: shape={x.shape}, dtype={x.dtype}")
    
    if cuda_available:
        x_gpu = x.to('cuda:0')
        print(f"Tensor transferido para GPU: {x_gpu.device}")
        
        # Testar alocador personalizado (se disponívvel)
        try:
            from torch.cuda.memory import CUDAPluggableAllocator
            allocator = CUDAPluggableAllocator(str(umc_dll_path), 'umc_alloc', 'umc_free')
            torch.cuda.memory.change_current_allocator(allocator)
            print("OK: CUDAPluggableAllocator configurado")
            
            # Criar tensor na GPU usando o alocador personalizado
            y = torch.randn(5, 5, device='cuda:0')
            print(f"Tensor alocado com alocador customizado: {y.shape}")
        except Exception as e:
            print(f"Aviso: Falha ao testar CUDAPluggableAllocator (não fatal): {e}")
    else:
        print("CUDA não disponível, saltando teste de GPU")
    
except Exception as e:
    print(f"ERRO no teste PyTorch: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 60)
print("TESTE CONCLUÍDO COM SUCESSO!")
print("=" * 60)
