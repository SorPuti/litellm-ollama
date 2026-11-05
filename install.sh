#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${LITELLM_OLLAMA_DIR:-${HOME}/.local/share/litellm-ollama}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-local-dev-change-me}"

command -v docker >/dev/null || { echo "Erro: Docker é obrigatório." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || {
  echo "Erro: Docker Compose v2 é obrigatório (comando: docker compose)." >&2
  exit 1
}

mkdir -p "${INSTALL_DIR}"

cat >"${INSTALL_DIR}/config.yaml" <<'YAML'
model_list:
  - model_name: "ollama/*"
    litellm_params:
      model: "ollama/*"
      api_base: os.environ/OLLAMA_API_BASE
      input_cost_per_token: 0
      output_cost_per_token: 0
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
litellm_settings:
  drop_params: true
YAML

cat >"${INSTALL_DIR}/docker-compose.yml" <<'YAML'
services:
  litellm:
    image: docker.litellm.ai/berriai/litellm:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:4000:4000"
    environment:
      LITELLM_MASTER_KEY: ${MASTER_KEY}
      OLLAMA_API_BASE: http://host.docker.internal:11434
      LITELLM_OFFLINE_MODE: "true"
    volumes:
      - ./config.yaml:/app/config.yaml:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    command: ["--config", "/app/config.yaml", "--port", "4000"]
YAML

cat >"${INSTALL_DIR}/.env" <<ENV
LITELLM_MASTER_KEY=${MASTER_KEY}
ENV

echo "Instalando LiteLLM local em ${INSTALL_DIR}..."
(cd "${INSTALL_DIR}" && docker compose up -d)

cat <<INFO

Pronto.

Proxy:  http://localhost:4000/v1
Chave:  ${MASTER_KEY}

Teste:
  curl http://localhost:4000/v1/chat/completions \\
    -H 'Authorization: Bearer ${MASTER_KEY}' \\
    -H 'Content-Type: application/json' \\
    -d '{"model":"llama3.2","messages":[{"role":"user","content":"oi"}]}'

No OpenCode, adicione o provider local em opencode.json e troque llama3.2
por qualquer nome exibido por `ollama list`:

  {
    "provider": {
      "litellm-local": {
        "npm": "@ai-sdk/openai-compatible",
        "name": "LiteLLM + Ollama (local)",
        "options": {
          "baseURL": "http://127.0.0.1:4000/v1",
          "apiKey": "${MASTER_KEY}"
        },
        "models": {"llama3.2": {"name": "Llama 3.2"}}
      }
    }
  }

Arquivos: ${INSTALL_DIR}
Parar:   (cd "${INSTALL_DIR}" && docker compose down)
INFO
