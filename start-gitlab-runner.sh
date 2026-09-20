#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="local-gitlab-runner"
IMAGE="gitlab/gitlab-runner:alpine"
NETWORK_NAME="local-gitlab-network"
GITLAB_CONTAINER="local-gitlab"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${RUNNER_TOKEN_FILE:-${SCRIPT_DIR}/runner-token}"
RUNNER_TOKEN="${GITLAB_RUNNER_TOKEN:-${1:-}}"

if [[ -z "${RUNNER_TOKEN}" && -f "${TOKEN_FILE}" ]]; then
    RUNNER_TOKEN="$(<"${TOKEN_FILE}")"
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Blad: Docker nie jest zainstalowany lub nie ma go w PATH." >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Blad: Docker nie dziala albo bieżący użytkownik nie ma do niego dostępu." >&2
    exit 1
fi

if ! docker container inspect "${GITLAB_CONTAINER}" >/dev/null 2>&1; then
    echo "Blad: najpierw uruchom ${GITLAB_CONTAINER} przez start-gitlab.sh." >&2
    exit 1
fi

if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    docker network create "${NETWORK_NAME}" >/dev/null
fi

docker network connect "${NETWORK_NAME}" "${GITLAB_CONTAINER}" 2>/dev/null || true

docker volume create local-gitlab-runner-config >/dev/null

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
        docker start "${CONTAINER_NAME}" >/dev/null
    fi

    if docker exec "${CONTAINER_NAME}" test -s /etc/gitlab-runner/config.toml; then
        if ! docker exec "${CONTAINER_NAME}" grep -q 'host.docker.internal:host-gateway' /etc/gitlab-runner/config.toml; then
            docker exec "${CONTAINER_NAME}" sed -i '/network_mode =/a\    extra_hosts = ["host.docker.internal:host-gateway"]' /etc/gitlab-runner/config.toml
            docker restart "${CONTAINER_NAME}" >/dev/null
        fi
        echo "GitLab Runner już istnieje: ${CONTAINER_NAME}"
        docker exec "${CONTAINER_NAME}" gitlab-runner verify || true
        exit 0
    fi

    echo "Kontener Runnera istnieje, ale nie jest zarejestrowany. Dokańczam rejestrację."
fi

if [[ -z "${RUNNER_TOKEN}" ]]; then
    echo "Brak tokenu Runnera." >&2
    echo "Utwórz Project runner w GitLabie: Settings > CI/CD > Runners." >&2
    echo "Zapisz token w pliku ${TOKEN_FILE} albo przekaż go przez GITLAB_RUNNER_TOKEN." >&2
    exit 1
fi

if ! docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    docker run --detach \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        --network "${NETWORK_NAME}" \
        --volume local-gitlab-runner-config:/etc/gitlab-runner \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        "${IMAGE}" >/dev/null
fi

docker exec "${CONTAINER_NAME}" gitlab-runner register \
    --non-interactive \
    --url "http://${GITLAB_CONTAINER}" \
    --clone-url "http://${GITLAB_CONTAINER}" \
    --token "${RUNNER_TOKEN}" \
    --executor docker \
    --docker-image alpine:latest \
    --docker-network-mode "${NETWORK_NAME}" \
    --docker-extra-hosts "host.docker.internal:host-gateway" \
    --description local-docker-runner >/dev/null

echo "Uruchomiono i zarejestrowano GitLab Runnera: ${CONTAINER_NAME}"
echo "Runner wykonuje joby w kontenerach Docker w sieci ${NETWORK_NAME}."
