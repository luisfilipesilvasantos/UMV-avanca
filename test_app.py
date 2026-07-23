#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Testes unitários básicos para app.py
"""

import sys
sys.path.insert(0, '.')

from app import (
    initialize_virtual_capacity,
    allocateSystemVirtual,
    enable_cuda_pinning,
    tier_manager_decide_tier_and_allocate,
    get_memory_stats
)


def test_basic_allocation():
    """Testa alocação básica sem pinning."""
    print("\n=== Teste 1: Alocação Básica ===")
    initialize_virtual_capacity(4*1024**3, 8*1024**3)  # 4GB VRAM + 8GB RAM
    tensor = allocateSystemVirtual(1024)  # Alocar 1KB
    print(f"[OK] Tensor alocado: {tensor.shape}, dtype={tensor.dtype}")
    assert tensor.numel() == 256, "Tamanho incorreto"


def test_pinning_warning():
    """Testa aviso ao habilitar pinning sem CUDA."""
    print("\n=== Teste 2: Pinning (sem CUDA) ===")
    enable_cuda_pinning(True)
    tensor = allocateSystemVirtual(1024)
    print(f"[OK] Tensor alocado em CPU: {tensor.device}")


def test_tier_manager():
    """Testa decisão do TierManager."""
    print("\n=== Teste 3: Tier Manager ===")
    tier_id, tensor = tier_manager_decide_tier_and_allocate(1024)
    print(f"[OK] Tier escolhido: {tier_id} (0=VRAM, 1=RAM), Tensor device: {tensor.device}")


def test_memory_stats():
    """Testa estatísticas de memória."""
    print("\n=== Teste 4: Estatísticas ===")
    stats = get_memory_stats()
    for k, v in stats.items():
        print(f"  {k}: {v}")


def test_capacity_exceeded():
    """Testa erro ao exceder capacidade."""
    print("\n=== Teste 5: Exceder Capacidade ===")
    # Redefinir capacidade para um valor pequeno (ex: 1KB VRAM + 1KB RAM)
    initialize_virtual_capacity(1024, 1024)  # Total = 2KB
    try:
        allocateSystemVirtual(3*1024)  # Tentar alocar 3KB (excede 2KB total)
        print("[ERRO] Deveria ter lançado MemoryError")
    except MemoryError as e:
        print(f"[OK] Erro esperado capturado: {e}")


if __name__ == '__main__':
    test_basic_allocation()
    test_pinning_warning()
    test_tier_manager()
    test_memory_stats()
    test_capacity_exceeded()
    print("\n=== Todos os testes concluídos ===")