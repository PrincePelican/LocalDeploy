#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="local-gitlab"
IMAGE="gitlab/gitlab-ce:latest"
HTTP_PORT="${GITLAB_HTTP_PORT:-8080}"
SSH_PORT="${GITLAB_SSH_PORT:-2222}"

show_root_password() {
    echo "Login administratora: root"

    if password_line="$(docker exec "${CONTAINER_NAME}" grep 'Password:' /etc/gitlab/initial_root_password 2>/dev/null)"; then
        echo "${password_line}"
    else
        echo "Hasło początkowe nie jest jeszcze dostępne. GitLab nadal się inicjalizuje."
        echo "Sprawdź później: sudo docker exec -it ${CONTAINER_NAME} grep 'Password:' /etc/gitlab/initial_root_password"
    fi
}

if ! command -v docker >/dev/null 2>&1; then
    echo "Blad: Docker nie jest zainstalowany lub nie ma go w PATH." >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Blad: Docker nie dziala albo bieżący użytkownik nie ma do niego dostępu." >&2
    exit 1
fi

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" == "true" ]]; then
        echo "GitLab już działa: http://localhost:${HTTP_PORT}"
        show_root_password
        exit 0
    fi

    docker start "${CONTAINER_NAME}" >/dev/null
    echo "Uruchomiono istniejący GitLab: http://localhost:${HTTP_PORT}"
    show_root_password
    exit 0
fi

docker volume create local-gitlab-config >/dev/null
docker volume create local-gitlab-logs >/dev/null
docker volume create local-gitlab-data >/dev/null

docker run --detach \
    --name "${CONTAINER_NAME}" \
    --hostname gitlab.local \
    --restart unless-stopped \
    --publish "${HTTP_PORT}:80" \
    --publish "${SSH_PORT}:22" \
    --shm-size 256m \
    --env GITLAB_OMNIBUS_CONFIG="external_url 'http://localhost:${HTTP_PORT}'; nginx['listen_port'] = 80; nginx['listen_https'] = false; gitlab_rails['gitlab_shell_ssh_port'] = ${SSH_PORT}" \
    --volume local-gitlab-config:/etc/gitlab \
    --volume local-gitlab-logs:/var/log/gitlab \
    --volume local-gitlab-data:/var/opt/gitlab \
    "${IMAGE}" >/dev/null

echo "Uruchomiono GitLab. Panel będzie dostępny za kilka minut: http://localhost:${HTTP_PORT}"
show_root_password
echo "SSH do repozytoriów używa portu ${SSH_PORT}."