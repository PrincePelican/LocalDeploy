#!/usr/bin/env bash

set -euo pipefail

OLLAMA_HOST_VALUE="${OLLAMA_HOST:-0.0.0.0:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-tobestyledintro/qwen3.8-9b-distill}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_LOG="${OLLAMA_LOG:-${HOME}/.local/state/ollama/ollama.log}"
OLLAMA_URL="http://127.0.0.1:${OLLAMA_PORT}"

if ! command -v ollama >/dev/null 2>&1; then
    echo "Blad: Ollama nie jest zainstalowana lub nie ma jej w PATH." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Blad: curl nie jest zainstalowany." >&2
    exit 1
fi

mkdir -p "$(dirname "${OLLAMA_LOG}")"

if curl --silent --show-error --fail --max-time 3 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
    if command -v ss >/dev/null 2>&1 && ss -ltn | grep -Eq "(0\.0\.0\.0|\*):${OLLAMA_PORT}[[:space:]]"; then
        echo "Ollama już działa i jest dostępna z kontenerów."
    else
        echo "Ollama działa, ale prawdopodobnie tylko na 127.0.0.1:${OLLAMA_PORT}." >&2
        echo "Zatrzymaj ją i uruchom ponownie tym skryptem." >&2
        exit 1
    fi
else
    echo "Uruchamiam Ollamę na ${OLLAMA_HOST_VALUE}..."
    nohup env OLLAMA_HOST="${OLLAMA_HOST_VALUE}" ollama serve \
        >>"${OLLAMA_LOG}" 2>&1 &

    for attempt in {1..30}; do
        if curl --silent --show-error --fail --max-time 2 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
            break
        fi
        if [[ "${attempt}" == 30 ]]; then
            echo "Blad: Ollama nie uruchomila API." >&2
            echo "Log: ${OLLAMA_LOG}" >&2
            exit 1
        fi
        sleep 1
    done
fi

echo "Sprawdzam model ${OLLAMA_MODEL}..."
if ! OLLAMA_HOST="${OLLAMA_HOST_VALUE}" ollama show "${OLLAMA_MODEL}" >/dev/null 2>&1; then
    echo "Pobieram model ${OLLAMA_MODEL}..."
    OLLAMA_HOST="${OLLAMA_HOST_VALUE}" ollama pull "${OLLAMA_MODEL}"
fi

echo "Ollama działa: ${OLLAMA_URL}"
echo "Model dostępny: ${OLLAMA_MODEL}"
echo "Log: ${OLLAMA_LOG}"
