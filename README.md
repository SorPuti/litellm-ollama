# LiteLLM + Ollama local

Este projeto expõe o Ollama por uma API compatível com OpenAI em
`http://localhost:4000/v1`. Qualquer modelo instalado no Ollama pode ser
selecionado no campo `model`, usando o nome retornado por `ollama list`.

## Instalação rápida em qualquer PC

Depois de publicar este repositório, a instalação fica:

```bash
curl -fsSL https://raw.githubusercontent.com/SorPuti/litellm-ollama/main/install.sh | bash
```

O instalador cria tudo em `~/.local/share/litellm-ollama`, inicia o container
e imprime o bloco pronto para colar no `opencode.json`. Para trocar a chave
durante a instalação:

```bash
curl -fsSL https://raw.githubusercontent.com/SorPuti/litellm-ollama/main/install.sh \\
  | LITELLM_MASTER_KEY=sk-minha-chave bash
```

## Pré-requisitos

- Docker com Compose;
- Ollama instalado e em execução;
- pelo menos um modelo baixado, por exemplo:

```bash
ollama pull llama3.2
ollama list
```

## Inicialização

```bash
cp .env.example .env
# opcional: edite .env e troque LITELLM_MASTER_KEY
docker compose up -d
docker compose logs -f litellm
```

Teste o proxy em outro terminal, substituindo `llama3.2` por qualquer nome
exato mostrado por `ollama list`:

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY:-sk-local-dev-change-me}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "messages": [{"role": "user", "content": "Responda em uma frase: oi"}]
  }'
```

Para ver os modelos publicados pelo proxy:

```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY:-sk-local-dev-change-me}"
```

## Usando no OpenCode

O OpenCode aceita provedores OpenAI-compatible. No `opencode.json` do projeto,
adicione o bloco que o instalador imprime. O `baseURL` deve terminar em `/v1`
e o ID em `models` deve ser exatamente um nome de `ollama list`. O LiteLLM já
aceita qualquer modelo no backend; o bloco do OpenCode só controla quais nomes
aparecem no seletor. Depois, use `/models` no OpenCode e escolha
`litellm-local/llama3.2`.

Fonte oficial do formato do provider: https://opencode.ai/docs/providers

## Usando um cliente OpenAI

```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-local-dev-change-me",
    base_url="http://localhost:4000/v1",
)

resposta = client.chat.completions.create(
    model="llama3.2",
    messages=[{"role": "user", "content": "Olá!"}],
)
print(resposta.choices[0].message.content)
```

## Parar e diagnosticar

```bash
docker compose down
docker compose logs --tail=100 litellm
curl http://localhost:11434/api/tags
```

Se o LiteLLM não conseguir falar com o Ollama, confirme que o Ollama está
rodando no host e que `OLLAMA_API_BASE` continua como
`http://host.docker.internal:11434`. Em Linux, o `extra_hosts` do Compose já
cria esse nome apontando para o host.

## Referências oficiais

- LiteLLM Proxy: https://docs.litellm.ai/docs/proxy_server
- Configuração do Proxy: https://docs.litellm.ai/docs/proxy/quick_start
- Provedores LiteLLM (inclui Ollama): https://docs.litellm.ai/docs/providers
