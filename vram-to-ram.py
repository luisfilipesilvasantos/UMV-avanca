import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

model_id = "teu_modelo_gigante_aqui"

# 1. Definir os limites de memória (Adapte à tua RTX 3060 12GB + RAM disponível)
max_memory = {
    0: "10GB",       # Deixa 2GB de VRAM livres para o sistema/contexto
    "cpu": "24GB",   # Limite de RAM que permites usar
    "disk": "50GB"   # Se a RAM encher, usa o disco (offload_folder)
}

# 2. Carregar o modelo com device_map="auto" e offload para disco se necessário
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    device_map="auto",
    max_memory=max_memory,
    offload_folder="C:/meu_projeto/offload_disk", # Pasta no SSD rápido!
    torch_dtype=torch.float16
)

tokenizer = AutoTokenizer.from_pretrained(model_id)

# 3. Inferência (Será mais lenta devido ao offload, mas NÃO vai crashar)
inputs = tokenizer("O que é memória unificada?", return_tensors="pt").to("cuda")
outputs = model.generate(**inputs, max_new_tokens=50)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))