from llama_cpp import Llama

# O modelo é mapeado na RAM (mmap=True), e apenas 35 camadas vão para a GPU (RTX 3060)
# O restante das camadas fica na RAM do sistema, com troca otimizada.
llm = Llama(
    model_path="C:/modelos/modelo-13b-Q4_K_M.gguf",
    n_gpu_layers=35,  # Ajusta até a VRAM ficar em ~10-11GB (monitória com nvidia-smi)
    n_ctx=4096,
    use_mmap=True,    # Crucial: evita carregar o modelo inteiro na RAM de uma vez
    use_mlock=False   # False permite que o OS mova partes não usadas para o Page File
)

output = llm("Q: O que é memória unificada? A:", max_tokens=50, echo=True)
print(output["choices"][0]["text"])