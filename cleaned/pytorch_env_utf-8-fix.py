#!/usr/bin/env python3
"""
Configuração de Ambiente PyTorch para Otimização de Memória

Este script configura variáveis de ambiente e utilitários para:
- Evitar fragmentação na VRAM (RTX 3060)
- Gerenciar memória com PYTORCH_CUDA_ALLOC_CONF
- Limitar uso de VRAM por processo com torch.cuda.set_per_process_memory_fraction
"""

import os
import sys
import torch
from typing import Optional


def configure_pytorch_environment(
    garbage_collection_threshold: float = 0.8,
    max_split_size_mb: int = 128,
    vram_fraction: Optional[float] = None,
    device_id: int = 0
) -> None:
    """
    Configura o ambiente PyTorch para otimizar uso de VRAM e evitar crashes.

    Args:
        garbage_collection_threshold (float): Limiar para coleta de lixo (padrão: 0.8)
        max_split_size_mb (int): Tamanho máximo de split em MB (padrão: 128)
        vram_fraction (Optional[float]): Fração da VRAM a usar (ex: 0.9 = 90%). Se None, usa total disponível.
        device_id (int): ID do dispositivo CUDA (padrão: 0)
    """

    # Configurar variáveis de ambiente para gerenciar fragmentação
    alloc_conf = f"garbage_collection_threshold:{garbage_collection_threshold},max_split_size_mb:{max_split_size_mb}"
    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = alloc_conf

    print(f"✅ PYTORCH_CUDA_ALLOC_CONF configurado: {alloc_conf}")

    # Verificar CUDA disponível
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA não está disponível. Verifique drivers NVIDIA e instalação do PyTorch.")

    device_count = torch.cuda.device_count()
    print(f"🖥️  Dispositivos CUDA detectados: {device_count}")

    if device_id >= device_count:
        raise ValueError(f"device_id={device_id} inválido. Apenas {device_count} dispositivos disponíveis.")

    # Configurar fração de VRAM (opcional)
    if vram_fraction is not None:
        if not 0.0 < vram_fraction <= 1.0:
            raise ValueError("vram_fraction deve estar entre 0 e 1 (ex: 0.9 para 90%)")

        torch.cuda.set_per_process_memory_fraction(vram_fraction, device=device_id)
        print(f"✅ VRAM limitada a {vram_fraction * 100:.0f}% do total na GPU {device_id}")

    # Mostrar info da GPU atual
    props = torch.cuda.get_device_properties(device_id)
    total_mem_gb = props.total_memory / (1024 ** 3)
    print(f"\n📊 GPU {device_id}: {props.name}")
    print(f"   VRAM Total: {total_mem_gb:.1f} GB")

    # Forçar limpeza de cache para garantir estado limpo após configuração
    torch.cuda.empty_cache()
    torch.cuda.synchronize()

    print("\n✅ Ambiente PyTorch otimizado e pronto para uso.")


def get_memory_stats(device_id: int = 0) -> dict:
    """
    Retorna estatísticas de memória CUDA em MB.

    Args:
        device_id (int): ID do dispositivo CUDA

    Returns:
        dict: Dicionário com 'allocated', 'reserved', 'free'
    """
    if not torch.cuda.is_available():
        return {}

    allocated = torch.cuda.memory_allocated(device_id) / (1024 ** 2)
    reserved = torch.cuda.memory_reserved(device_id) / (1024 ** 2)
    total = torch.cuda.get_device_properties(device_id).total_memory / (1024 ** 2)
    free = total - reserved

    return {
        "allocated_mb": allocated,
        "reserved_mb": reserved,
        "free_mb": free,
        "total_mb": total
    }


def print_memory_report(device_id: int = 0) -> None:
    """
    Imprime relatório detalhado de memória CUDA.

    Args:
        device_id (int): ID do dispositivo CUDA
    """
    stats = get_memory_stats(device_id)
    if not stats:
        print("❌ CUDA não disponível")
        return

    print(f"\n📈 Relatório de Memória GPU {device_id}:")
    print(f"   Alocada:  {stats['allocated_mb']:.1f} MB")
    print(f"   Reservada: {stats['reserved_mb']:.1f} MB")
    print(f"   Livre:    {stats['free_mb']:.1f} MB")
    print(f"   Total:    {stats['total_mb']:.1f} MB")


if __name__ == "__main__":
    # Exemplo de uso
    try:
        configure_pytorch_environment(
            garbage_collection_threshold=0.8,
            max_split_size_mb=128,
            vram_fraction=0.9,  # Usar até 90% da VRAM (evita OOM)
            device_id=0
        )
        print_memory_report(device_id=0)
    except Exception as e:
        print(f"❌ Erro na configuração: {e}")
        sys.exit(1)
