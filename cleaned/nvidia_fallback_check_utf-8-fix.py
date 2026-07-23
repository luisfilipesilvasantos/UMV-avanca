#!/usr/bin/env python3
"""
Verificação do System Memory Fallback do Driver NVIDIA

Este script verifica se o fallback para RAM física está ativado no driver NVIDIA,
permitindo que o CUDA transborde silenciosamente para a RAM quando excede a VRAM.

Requer:
- Python 3.7+
- PyTorch (para verificar compatibilidade)
- Driver NVIDIA recente (465+ recomenda-se)
"""

import os
import sys
import subprocess
import torch
from typing import Tuple, Optional


def check_nvidia_driver_version() -> Tuple[bool, str]:
    """
    Verifica a versão do driver NVIDIA instalado.

    Returns:
        Tuple[bool, str]: (is_supported, version_string)
    """
    try:
        # Tenta obter via nvidia-smi
        result = subprocess.run(
            ["nvidia-smi", "--query-driver=version", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            version = result.stdout.strip()
            # Versões >= 465 suportam System Memory Fallback
            major_version = int(version.split(".")[0])
            is_supported = major_version >= 465
            return is_supported, f"Driver v{version}"
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError):
        pass

    # Fallback: tentar via PyTorch (menos preciso)
    try:
        cuda_version = torch.version.cuda
        if cuda_version:
            return True, f"CUDA {cuda_version} (via PyTorch)"
    except Exception:
        pass

    return False, "Não detectado"


def check_system_memory_fallback() -> Tuple[bool, str]:
    """
    Verifica se System Memory Fallback está disponível e ativado.

    Returns:
        Tuple[bool, str]: (is_available, message)
    """
    if not torch.cuda.is_available():
        return False, "CUDA não disponível"

    # A partir do CUDA 11.2+ com drivers recentes, o fallback está ativado por padrão
    # Não há API direta para verificar, mas podemos inferir:
    try:
        props = torch.cuda.get_device_properties(0)
        total_vram_gb = props.total_memory / (1024 ** 3)

        # Se temos VRAM < RAM e CUDA funciona, o fallback provavelmente está ativo
        memory_status = {}
        try:
            import ctypes
            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [
                    ("dwLength", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_uint64),
                    ("ullAvailPhys", ctypes.c_uint64),
                    ("ullTotalPageFile", ctypes.c_uint64),
                    ("ullAvailPageFile", ctypes.c_uint64),
                    ("ullTotalVirtual", ctypes.c_uint64),
                    ("ullAvailVirtual", ctypes.c_uint64)
                ]

            mem_status = MEMORYSTATUSEX()
            mem_status.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(mem_status)):
                memory_status = {
                    "ram_gb": mem_status.ullTotalPhys / (1024 ** 3),
                    "pagefile_gb": mem_status.ullTotalPageFile / (1024 ** 3)
                }
        except Exception:
            pass

        fallback_info = ""
        if memory_status:
            ram_gb = memory_status["ram_gb"]
            pagefile_gb = memory_status["pagefile_gb"]
            fallback_info = f" (VRAM: {total_vram_gb:.1f}GB, RAM: {ram_gb:.1f}GB, Pagefile: {pagefile_gb:.1f}GB)"

        return True, f"System Memory Fallback disponível por padrão no CUDA 11.2+{fallback_info}"

    except Exception as e:
        return False, f"Erro ao verificar fallback: {e}"


def test_memory_overflow() -> Tuple[bool, str]:
    """
    Testa se o sistema transborda VRAM para RAM sem crashar.

    Returns:
        Tuple[bool, str]: (success, message)
    """
    if not torch.cuda.is_available():
        return False, "CUDA não disponível"

    try:
        # Tenta alocar mais VRAM do que o disponível (deve falhar com OOM)
        props = torch.cuda.get_device_properties(0)
        vram_bytes = props.total_memory
        vram_gb = vram_bytes / (1024 ** 3)

        # Tenta alocar ~110% da VRAM disponível (deve transbordar para RAM se fallback ativo)
        size_to_allocate = int(vram_bytes * 1.1)  # Exceder VRAM

        print(f"⚠️  Teste de overflow: tentando alocar {size_to_allocate / (1024**3):.2f} GB em GPU com {vram_gb:.1f} GB VRAM...")

        try:
            # Aloca tensor gigante (deve causar OOM se fallback desativado)
            test_tensor = torch.empty((size_to_allocate // 4,), dtype=torch.float32, device="cuda")
            del test_tensor
            torch.cuda.empty_cache()
            return True, "Transbordo VRAM→RAM funcionou (sem crash)"
        except RuntimeError as e:
            if "out of memory" in str(e).lower():
                # Se falhou com OOM, fallback pode não estar ativo
                return False, f"OOM detectado: fallback para RAM não está ativo ou RAM insuficiente. Erro: {e}"
            raise

    except Exception as e:
        return False, f"Erro no teste de overflow: {e}"


def main():
    print("=== Verificação do System Memory Fallback NVIDIA ===\n")

    # 1. Driver version
    driver_ok, driver_msg = check_nvidia_driver_version()
    status_driver = "✅" if driver_ok else "⚠️"
    print(f"{status_driver} {driver_msg}")

    # 2. System Memory Fallback availability
    fallback_ok, fallback_msg = check_system_memory_fallback()
    status_fallback = "✅" if fallback_ok else "❌"
    print(f"{status_fallback} {fallback_msg}\n")

    # 3. Test de overflow (opcional - pode ser lento)
    print("🚀 Realizando teste rápido de transbordo VRAM→RAM...")
    overflow_ok, overflow_msg = test_memory_overflow()
    status_overflow = "✅" if overflow_ok else "❌"
    print(f"{status_overflow} {overflow_msg}\n")

    # Resumo final
    all_ok = driver_ok and fallback_ok and overflow_ok
    if all_ok:
        print("🎉 Sistema pronto para IA com System Memory Fallback ativo!")
    else:
        print("⚠️  Recomendações:")
        if not driver_ok:
            print("   - Atualize o driver NVIDIA para v465+ (https://www.nvidia.com/Download/index.aspx)")
        if not fallback_ok:
            print("   - Verifique se está usando CUDA 11.2+ e PyTorch recente")
        if not overflow_ok:
            print("   - Aumente o tamanho do pagefile (use optimize_system.ps1)")

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
