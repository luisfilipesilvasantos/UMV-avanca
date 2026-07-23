import os
import re

EXTENSOES = {'.cpp', '.h', '.hpp'}

def corrigir_conteudo(conteudo):
    # 1. Corrige o padrão comum: \n seguido de quebra de linha real antes das aspas de fecho
    # Ex: L"Texto\n\n" ou "Texto\n\n"
    conteudo_corrigido = re.sub(r'(\\n)\s*\n\s*"', r'\1"', conteudo)
    
    # 2. Corrige strings que foram deixadas abertas e saltaram de linha fisicamente
    linhas = conteudo_corrigido.splitlines()
    linhas_corrigidas = []
    dentro_de_string = False
    linha_acumulada = ""
    
    for i, linha in enumerate(linhas):
        # Ignorar comentários completos de linha para evitar falsos positivos
        if linha.strip().startswith("//"):
            linhas_corrigidas.append(linha)
            continue
            
        # Contar aspas que não são precedidas por um caractere de escape (\")
        # Também lida com strings wide (L"...")
        aspas = re.findall(r'(?<!\\)"', linha)
        
        if dentro_de_string:
            # Se já estávamos dentro de uma string, estamos à procura do fecho
            linha_acumulada += " " + linha.lstrip()
            if len(aspas) % 2 != 0: # Encontrou um número ímpar de aspas não-escapadas, fechou a string
                linhas_corrigidas.append(linha_acumulada)
                linha_acumulada = ""
                dentro_de_string = False
            else:
                # Continua na próxima linha se ainda não fechou
                pass
        else:
            if len(aspas) % 2 != 0: # Número ímpar de aspas indica que a string ficou aberta e saltou de linha
                linha_acumulada = linha.rstrip() + "\\n" # Adiciona o escape de newline explícito
                dentro_de_string = True
            else:
                linhas_corrigidas.append(linha)
                
    # Se por algum motivo o ficheiro acabar e a string ficar aberta
    if linha_acumulada:
        linhas_corrigidas.append(linha_acumulada)
        
    return "\n".join(linhas_corrigidas)

def processar_diretorio():
    print("=========================================================")
    # Identifica o teu utilizador no log para saberes exatamente onde está a atuar
    print(" Corretor Automático de Sintaxe C++ (MSVC C2001)")
    print("=========================================================")
    
    corrigidos = 0
    erros = 0
    
    for raiz, _, ficheiros in os.walk('.'):
        if 'build' in raiz.split(os.sep):
            continue
            
        for ficheiro in ficheiros:
            ext = os.path.splitext(ficheiro)[1].lower()
            if ext in EXTENSOES:
                caminho = os.path.join(raiz, ficheiro)
                
                try:
                    with open(caminho, 'r', encoding='utf-8') as f:
                        original = f.read()
                        
                    corrigido = corrigir_conteudo(original)
                    
                    if corrigido != original:
                        with open(caminho, 'w', encoding='utf-8') as f:
                            f.write(corrigido)
                        print(f"[CORRIGIDO] {caminho}")
                        corrigidos += 1
                    else:
                        print(f"[OK]        {caminho}")
                        
                except Exception as e:
                    print(f"[ERRO]      Não foi possível ler {caminho}: {e}")
                    erros += 1
                    
    print(f"\nProcesso Concluído! Ficheiros corrigidos: {corrigidos} | Erros: {erros}")

if __name__ == "__main__":
    processar_diretorio()
