#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${K3D_CLUSTER_NAME:-localdeploy}"
HTTP_PORT="${K3D_HTTP_PORT:-8040}"
KUBE_CONTEXT="k3d-${CLUSTER_NAME}"

if ! [[ "${HTTP_PORT}" =~ ^[0-9]+$ ]] || ((HTTP_PORT < 1 || HTTP_PORT > 65535)); then
    echo "Błąd: K3D_HTTP_PORT musi być portem z zakresu 1-65535." >&2
    exit 1
fi

for command_name in docker k3d kubectl; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Błąd: wymagane narzędzie '${command_name}' nie jest zainstalowane lub nie ma go w PATH." >&2
        exit 1
    fi
done

if ! docker info >/dev/null 2>&1; then
    echo "Błąd: Docker nie działa albo bieżący użytkownik nie ma do niego dostępu." >&2
    exit 1
fi

if k3d cluster list | awk -v name="${CLUSTER_NAME}" '$1 == name { found = 1 } END { exit !found }'; then
    echo "Uruchamiam istniejący klaster ${CLUSTER_NAME}..."
    k3d cluster start "${CLUSTER_NAME}"
else
    echo "Tworzę lokalny klaster k3d ${CLUSTER_NAME}..."
    k3d cluster create "${CLUSTER_NAME}" \
        --servers 1 \
        --agents 1 \
        --port "${HTTP_PORT}:80@loadbalancer" \
        --wait
fi

kubectl --context "${KUBE_CONTEXT}" create namespace dev --dry-run=client -o yaml |
    kubectl --context "${KUBE_CONTEXT}" apply -f -
kubectl --context "${KUBE_CONTEXT}" create namespace staging --dry-run=client -o yaml |
    kubectl --context "${KUBE_CONTEXT}" apply -f -
kubectl --context "${KUBE_CONTEXT}" create namespace live --dry-run=client -o yaml |
    kubectl --context "${KUBE_CONTEXT}" apply -f -

echo
echo "Klaster działa. Kontekst Kubernetes: ${KUBE_CONTEXT}"
echo "Utworzone namespace'y: dev, staging, live"
echo "Namespace live pozostaje pusty do czasu skonfigurowania wdrożenia produkcyjnego."
echo "Port localhost:${HTTP_PORT} jest przekierowany do HTTP ingressu klastra."
echo "Samo przekierowanie portu nie wdraża aplikacji ani nie tworzy reguły ingress."
echo
echo "Sprawdź stan klastra:"
echo "  kubectl --context ${KUBE_CONTEXT} get nodes"
echo "  kubectl --context ${KUBE_CONTEXT} get namespaces"
