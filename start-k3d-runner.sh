#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="local-k3d-runner"
IMAGE="gitlab/gitlab-runner:alpine"
CONFIG_VOLUME="local-k3d-runner-config"
GITLAB_URL="${GITLAB_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${RUNNER_TOKEN_FILE:-${SCRIPT_DIR}/shellrunner-token}"
KUBECONFIG_DIR="${HOME}/.kube"
RUNNER_TOKEN=""

if [[ ! -s "${TOKEN_FILE}" ]]; then
    echo "Brak tokenu runnera w pliku ${TOKEN_FILE}." >&2
    exit 1
fi

chmod 600 "${TOKEN_FILE}"
RUNNER_TOKEN="$(<"${TOKEN_FILE}")"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker nie jest zainstalowany lub nie ma go w PATH." >&2
    exit 1
fi

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "Brak dostępu do Dockera i polecenia sudo." >&2
        exit 1
    fi
    sudo -v
    DOCKER=(sudo docker)
fi

"${DOCKER[@]}" info >/dev/null

if [[ ! -d "${KUBECONFIG_DIR}" || ! -s "${KUBECONFIG_DIR}/config" ]]; then
    echo "Nie znaleziono kubeconfigu w ${KUBECONFIG_DIR}/config." >&2
    exit 1
fi

for tool in git k3d kubectl; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "Wymagane narzędzie '${tool}' nie jest zainstalowane lub nie ma go w PATH." >&2
        exit 1
    fi
done

if ! kubectl --context k3d-localdeploy cluster-info >/dev/null; then
    echo "Nie można połączyć się z klastrem k3d-localdeploy." >&2
    exit 1
fi

"${DOCKER[@]}" volume create "${CONFIG_VOLUME}" >/dev/null

if ! "${DOCKER[@]}" container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    "${DOCKER[@]}" run --detach \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        --network host \
        --volume "${CONFIG_VOLUME}:/etc/gitlab-runner" \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        "${IMAGE}" >/dev/null
fi

if [[ "$("${DOCKER[@]}" inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
    "${DOCKER[@]}" start "${CONTAINER_NAME}" >/dev/null
fi

if "${DOCKER[@]}" exec "${CONTAINER_NAME}" test -s /etc/gitlab-runner/config.toml; then
    echo "Runner ${CONTAINER_NAME} ma już konfigurację. Weryfikuję rejestrację..."
    "${DOCKER[@]}" exec "${CONTAINER_NAME}" gitlab-runner verify
    exit 0
fi

"${DOCKER[@]}" exec \
    --env "RUNNER_TOKEN=${RUNNER_TOKEN}" \
    --env "GITLAB_URL=${GITLAB_URL}" \
    --env "KUBECONFIG_DIR=${KUBECONFIG_DIR}" \
    "${CONTAINER_NAME}" \
    sh -ec '
        gitlab-runner register \
            --non-interactive \
            --url "${GITLAB_URL}" \
            --clone-url "${GITLAB_URL}" \
            --token "${RUNNER_TOKEN}" \
            --executor docker \
            --docker-image alpine:latest \
            --docker-network-mode host \
            --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
            --docker-volumes "${KUBECONFIG_DIR}:/root/.kube:ro" \
            --description local-k3d-docker-runner
    ' >/dev/null

"${DOCKER[@]}" exec "${CONTAINER_NAME}" gitlab-runner verify
echo "Runner Docker local-k3d jest zarejestrowany."
echo "Joby używają hostowej sieci oraz lokalnego Dockera i klastra k3d."
