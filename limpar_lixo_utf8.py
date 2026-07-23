import os
import re

# Padrões Regex para capturar o lixo
LIXO_INVISIVEL = re.compile(r'[\ufeff\u200b\u200c\u200d\u2060\u200e\u200f]')
ASPAS_CURVAS = re.compile(r'[\u201c\u201d]')
ASPAS_SIMPLES_CURVAS = re.compile(r'[\u2018\u2019]')
TRACOS_LONGOS = re.compile(r'[\u2013\u2014]')
ESPACO_INQUEBRAVEL = re.compile(r'\u00a0')

EXTENSOES_ALVO = {'.cpp', '.h', '.hpp', '.c', '.txt', '.cmake', '.py'}

def limpar_direorio(diretorio_raiz='.'):
    print("=================================================================")
    print(" Limpador de Lixo UTF-8 para C++ / CMake")
    print("=================================================================")
    
    verificados = 0
    modificados = 0

    for raiz, _, ficheiros in os.walk(diretorio_raiz):
        # Ignorar a pasta de build para não mexer nos gerados pelo CMake
        if 'build' in raiz.split(os.sep):
            continue
            
        for ficheiro in ficheiros:
            ext = os.path.splitext(ficheiro)[1].lower()
            if ext in EXTENSOES_ALVO:
                caminho_completo = os.path.join(raiz, ficheiro)
                verificados += 1
                
                try:
                    # Ler com utf-8-sig para remover BOM automaticamente na leitura
                    with open(caminho_completo, 'r', encoding='utf-8-sig') as f:
                        conteudo_original = f.read()
                except UnicodeDecodeError:
                    print(f"[ERRO DE CODIFICAÇÃO] {caminho_completo}")
                    continue
                except Exception as e:
                    print(f"[ERRO] {caminho_completo}: {e}")
                    continue

                conteudo_limpo = LIXO_INVISIVEL.sub('', conteudo_original)
                conteudo_limpo = ASPAS_CURVAS.sub('"', conteudo_limpo)
                conteudo_limpo = ASPAS_SIMPLES_CURVAS.sub("'", conteudo_limpo)
                conteudo_limpo = TRACOS_LONGOS.sub('-', conteudo_limpo)
                conteudo_limpo = ESPACO_INQUEBRAVEL.sub(' ', conteudo_limpo)

                if conteudo_limpo != conteudo_original:
                    # Salvar em utf-8 puro (sem BOM)
                    with open(caminho_completo, 'w', encoding='utf-8') as f:
                        f.write(conteudo_limpo)
                    print(f"[LIMPO] {caminho_completo}")
                    modificados += 1

    print(f"\nConcluído! Ficheiros verificados: {verificados} | Ficheiros limpos: {modificados}")

if __name__ == '__main__':
    limpar_direorio()
