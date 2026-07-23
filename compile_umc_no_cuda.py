#!/usr/bin/env python3
"""
Script para compilar o ficheiro umc_no_cuda.cpp usando cl.exe diretamente.
"""
import subprocess
import sys

def main():
    # Compilação direta com cl.exe (Visual Studio Compiler)
    # Inclui os headers necessários e gera um executável
    cmd = [
        "cl.exe",
        "/EHsc",
        "/Fe:umc_no_cuda.exe",
        "umc_no_cuda.cpp",
        "VirtualGpuMemory.cpp"
    ]

    print(f"Compilando com comando: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        print("\nCompilação bem-sucedida!")
        print(result.stdout)
    else:
        print("\nErro na compilação:")
        print(result.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
