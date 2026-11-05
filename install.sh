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

if ! command -v ollama >/dev/null 2>&1; then
  echo "Erro: Ollama não foi encontrado neste PC." >&2
  exit 1
fi

MODEL_NAMES="$(ollama list | awk 'NR > 1 && $1 != "" { print $1 }')"
if [ -z "${MODEL_NAMES}" ]; then
  echo "Erro: nenhum modelo instalado no Ollama. Use: ollama pull <modelo>" >&2
  exit 1
fi

{
  echo "model_list:"
  while IFS= read -r model; do
    printf '  - model_name: "%s"\n' "${model}"
    printf '    litellm_params:\n'
    printf '      model: "ollama/%s"\n' "${model}"
    printf '      api_base: os.environ/OLLAMA_API_BASE\n'
    printf '      input_cost_per_token: 0\n'
    printf '      output_cost_per_token: 0\n'
  done <<MODELS
${MODEL_NAMES}
MODELS
  cat <<'YAML'
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
litellm_settings:
  drop_params: true
YAML
} >"${INSTALL_DIR}/config.yaml"

cat >"${INSTALL_DIR}/docker-compose.yml" <<'YAML'
services:
  litellm:
    image: docker.litellm.ai/berriai/litellm:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:4000:4000"
    environment:
      LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:-sk-local-dev-change-me}
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

configure_opencode() {
  local config="${HOME}/.config/opencode/opencode.json"
  if [ ! -f "${config}" ]; then
    echo "OpenCode não encontrado; configuração automática ignorada."
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 não encontrado; configuração automática do OpenCode ignorada."
    return 0
  fi

  cp "${config}" "${config}.bak.$(date +%Y%m%d%H%M%S)"
  OPENCODE_CONFIG="${config}" OPENCODE_MASTER_KEY="${MASTER_KEY}" python3 - <<'PY'
import json
import os
import subprocess

config_path = os.environ["OPENCODE_CONFIG"]
try:
    data = json.loads(open(config_path, encoding="utf-8").read())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Configuração do OpenCode inválida; backup preservado: {exc}")

models = []
try:
    result = subprocess.run(["ollama", "list"], check=True, capture_output=True, text=True)
    for line in result.stdout.splitlines()[1:]:
        name = line.split()[0] if line.split() else ""
        if name and name not in models:
            models.append(name)
except (FileNotFoundError, subprocess.CalledProcessError):
    pass

if not models:
    models = ["llama3.2:3b"]

data.setdefault("providers", {})["litellm-local"] = {
    "name": "LiteLLM + Ollama (local)",
    "package": "@opencode/ai/providers/openai-compatible",
    "settings": {
        "baseURL": "http://127.0.0.1:4000/v1",
        "apiKey": os.environ["OPENCODE_MASTER_KEY"],
    },
    "models": {model: {"name": model} for model in models},
}

with open(config_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
print("Modelos configurados no OpenCode: " + ", ".join(models))
PY
}

configure_opencode

cat <<INFO

Pronto.

Proxy:  http://localhost:4000/v1
Chave:  ${MASTER_KEY}

Teste:
  curl http://localhost:4000/v1/chat/completions \\
    -H 'Authorization: Bearer ${MASTER_KEY}' \\
    -H 'Content-Type: application/json' \\
    -d '{"model":"llama3.2","messages":[{"role":"user","content":"oi"}]}'

O OpenCode foi configurado automaticamente com os modelos instalados.
Use `/models` e selecione `litellm-local/<nome-do-modelo>`:

  {
    "provider": {
      "litellm-local": {
        "package": "@opencode/ai/providers/openai-compatible",
        "name": "LiteLLM + Ollama (local)",
        "settings": {
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
