#!/bin/bash

set -euo pipefail

# Helpers para GitHub Actions (grupos plegables)
gh_group() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::group::$*"
  else
    echo "[INFO] $*"
  fi
}

gh_group_end() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::endgroup::"
  fi
}

# Ejecuta comandos con privilegios (root o sudo) cuando sea necesario.
run_privileged() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${VALUES_FILE:-${SCRIPT_DIR}/values/argocd-values.yaml}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_RELEASE_NAME="${ARGOCD_RELEASE_NAME:-argocd}"
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-10m}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-}"

echo "[INFO] Bootstrap de Argo CD para laboratorio K3s"

if [ ! -f "$VALUES_FILE" ]; then
  echo "[ERROR] No existe el values file: $VALUES_FILE"
  exit 1
fi

if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

gh_group "Prechecks"
if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl no esta instalado"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[ERROR] kubectl no esta instalado"
  exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "[ERROR] No hay acceso al cluster. Verifica KUBECONFIG y estado de K3s"
  exit 1
fi
gh_group_end

gh_group "Helm"
if ! command -v helm >/dev/null 2>&1; then
  echo "[INFO] Helm no esta instalado, instalando..."
  if [ "${EUID:-$(id -u)}" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo -n bash
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
  fi
else
  echo "[INFO] Helm ya estaba instalado"
fi

helm version --short
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update
gh_group_end

gh_group "Argo CD"
if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
  echo "[INFO] Namespace $ARGOCD_NAMESPACE ya existe"
else
  echo "[INFO] Creando namespace $ARGOCD_NAMESPACE"
  kubectl create namespace "$ARGOCD_NAMESPACE"
fi

if helm status "$ARGOCD_RELEASE_NAME" -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
  echo "[INFO] Argo CD ya esta instalado (release: $ARGOCD_RELEASE_NAME). Se aplica upgrade idempotente"
else
  echo "[INFO] Argo CD no existe. Se instalara release: $ARGOCD_RELEASE_NAME"
fi

HELM_ARGS=(
  upgrade --install "$ARGOCD_RELEASE_NAME" argo/argo-cd
  --namespace "$ARGOCD_NAMESPACE"
  --create-namespace
  --values "$VALUES_FILE"
  --wait
  --timeout "$ARGOCD_WAIT_TIMEOUT"
)

if [ -n "$ARGOCD_CHART_VERSION" ]; then
  HELM_ARGS+=(--version "$ARGOCD_CHART_VERSION")
fi

helm "${HELM_ARGS[@]}"

echo "[INFO] Verificando despliegue de Argo CD"
kubectl -n "$ARGOCD_NAMESPACE" get pods -o wide
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s || true
kubectl -n "$ARGOCD_NAMESPACE" rollout status statefulset/argocd-application-controller --timeout=300s || true

echo "[INFO] Bootstrap de Argo CD finalizado"
echo "[INFO] Admin password (si existe):"
kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true
echo ""
gh_group_end
