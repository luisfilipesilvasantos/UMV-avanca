#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
FASE 0 — Fundação (bloqueante)
Implementação inicial do gerenciador de memória virtual com pinning CUDA.
Compatível com ambientes com e sem suporte a CUDA.
"""

import torch
from typing import Optional, Tuple

# Verificar se PyTorch tem suporte a CUDA
cuda_enabled = torch.cuda.is_available() if hasattr(torch, 'cuda') else False
if cuda_enabled:
    try:
        torch.cuda.init()
    except Exception as e:
        print(f"Aviso: Falha ao inicializar CUDA ({e}). Modo fallback ativado.")
        cuda_enabled = False

device_count = torch.cuda.device_count() if cuda_enabled else 0
m_totalVirtualCapacity: Optional[int] = None
m_vramCapacity: Optional[int] = None
m_ramCapacity: Optional[int] = None
m_cudaPinnedEnabled: bool = False


def allocateSystemVirtual(size_bytes: int, device_id: int = 0) -> torch.Tensor:
    """
    Aloca memória virtual (pode ser VRAM ou RAM).
    Se pinning CUDA estiver habilitado e CUDA disponível, usa host-pinned memory para transferências rápidas.
    
    :param size_bytes: Tamanho em bytes a alocar
    :param device_id: ID da GPU alvo (0 por padrão)
    :return: Tensor alocado na GPU ou Host (dependendo do tier decidido pelo TierManager)
    """
    global m_cudaPinnedEnabled, m_totalVirtualCapacity
    
    if m_totalVirtualCapacity is None:
        raise RuntimeError("Capacidade virtual não inicializada. Chame initialize_virtual_capacity().")
    
    # Verificar se o tamanho excede a capacidade total (VRAM + RAM)
    current_usage = torch.cuda.memory_allocated(device_id) if cuda_enabled and device_id < device_count else 0
    if current_usage + size_bytes > m_totalVirtualCapacity:
        raise MemoryError(f"Tentativa de alocar {size_bytes} bytes excede capacidade virtual total ({m_totalVirtualCapacity}).")
    
    # Se pinning estiver habilitado e CUDA disponível, usar host-pinned memory
    if m_cudaPinnedEnabled and cuda_enabled and device_id < device_count:
        try:
            cpu_tensor = torch.empty(size_bytes // 4, dtype=torch.float32, pin_memory=True)
            return cpu_tensor.to(device=f'cuda:{device_id}')
        except Exception as e:
            print(f"Pinning falhou ({e}), usando alocação padrão.")
    
    # Fallback: alocar diretamente na GPU ou CPU dependendo do device_id
    if cuda_enabled and device_id < device_count:
        return torch.empty(size_bytes // 4, dtype=torch.float32, device=f'cuda:{device_id}')
    else:
        return torch.empty(size_bytes // 4, dtype=torch.float32)


def initialize_virtual_capacity(vram: int, ram: int) -> None:
    """
    Inicializa a capacidade total de memória virtual (VRAM + RAM).
    
    :param vram: Capacidade em bytes da VRAM disponível
    :param ram: Capacidade em bytes da RAM disponível
    """
    global m_totalVirtualCapacity, m_vramCapacity, m_ramCapacity
    
    # Se não houver GPU, usar apenas RAM
    if not cuda_enabled:
        vram = 0
    
    m_vramCapacity = vram
    m_ramCapacity = ram
    m_totalVirtualCapacity = vram + ram
    print(f"Capacidade virtual inicializada: VRAM={vram/1e9:.2f}GB, RAM={ram/1e9:.2f}GB, Total={(vram+ram)/1e9:.2f}GB")


def enable_cuda_pinning(enabled: bool = True) -> None:
    """
    Habilita/desabilita o uso de memória pinned CUDA para transferências rápidas.
    
    :param enabled: Se True, usa host-pinned memory (se disponível)
    """
    global m_cudaPinnedEnabled
    if not cuda_enabled and enabled:
        print("Aviso: CUDA não disponível. Pinning será ignorado.")
    m_cudaPinnedEnabled = enabled
    print(f"CUDA Pinning {'habilitado' if enabled else 'desabilitado'} (CUDA {'' if cuda_enabled else 'NÃO '}disponível)")


# Hooks para ligar ao TierManager::decideTierAndAllocate()
def tier_manager_decide_tier_and_allocate(size_bytes: int, device_id: int = 0) -> Tuple[int, torch.Tensor]:
    """
    Hook simulando a decisão do TierManager sobre onde alocar (VRAM/RAM).
    Retorna o ID da 'tier' escolhida e o tensor alocado.
    
    :param size_bytes: Tamanho em bytes a alocar
    :param device_id: ID da GPU alvo
    :return: Tuple[tier_id, tensor_alocado]
             tier_id = 0 para VRAM (GPU), tier_id = 1 para RAM (CPU)
    """
    global m_vramCapacity, m_ramCapacity
    
    if m_totalVirtualCapacity is None:
        raise RuntimeError("Capacidade virtual não inicializada.")
    
    # Lógica simples de tier: se houver VRAM disponível e CUDA estiver ativo, usar GPU
    current_vram_usage = torch.cuda.memory_allocated(device_id) if cuda_enabled and device_id < device_count else 0
    vram_available = m_vramCapacity - current_vram_usage if cuda_enabled and device_id < device_count else 0
    
    if vram_available >= size_bytes and cuda_enabled and device_id < device_count:
        # Alocar na VRAM (Tier 0)
        tensor = allocateSystemVirtual(size_bytes, device_id=device_id)
        return (0, tensor)
    else:
        # Fallback para RAM (Tier 1)
        cpu_tensor = torch.empty(size_bytes // 4, dtype=torch.float32)  # Alocar em CPU
        return (1, cpu_tensor)


def get_memory_stats() -> dict:
    """
    Retorna estatísticas de memória atual.
    
    :return: Dicionário com VRAM/RAM usada/disponível
    """
    stats = {
        'vram_used': 0,
        'vram_total': m_vramCapacity or 0,
        'ram_used': 0,  # Em Python puro é difícil medir RAM exata sem psutil
        'ram_total': m_ramCapacity or 0,
    }
    
    if cuda_enabled and device_count > 0:
        stats['vram_used'] = torch.cuda.memory_allocated(0)
        stats['vram_reserved'] = torch.cuda.memory_reserved(0)
    
    return stats
