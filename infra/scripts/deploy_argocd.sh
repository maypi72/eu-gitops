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
VALUES_FILE="${VALUES_FILE:-${SCRIPT_DIR}/../values/argocd-values.yaml}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_RELEASE_NAME="${ARGOCD_RELEASE_NAME:-argocd}"
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-10m}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-}"

echo "[INFO] Despliegue de Infra Argo CD para laboratorio K3s"

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

HELM_VERSION="$(helm version --short 2>/dev/null || true)"
if ! echo "$HELM_VERSION" | grep -q '^v3\.'; then
  echo "[WARN] Helm detectado no es v3 (${HELM_VERSION:-desconocido}). Instalando Helm v3..."
  if [ "${EUID:-$(id -u)}" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo -n bash
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
  fi
fi

HELM_VERSION="$(helm version --short 2>/dev/null || true)"
if ! echo "$HELM_VERSION" | grep -q '^v3\.'; then
  echo "[ERROR] No se pudo validar Helm v3. Version actual: ${HELM_VERSION:-desconocida}"
  exit 1
fi
echo "[INFO] Helm version: $HELM_VERSION"

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

if [ -z "$ARGOCD_CHART_VERSION" ]; then
  ARGOCD_CHART_VERSION="$(helm search repo argo/argo-cd --versions | awk 'NR==2 {print $2}')"
fi

if [ -z "$ARGOCD_CHART_VERSION" ]; then
  echo "[ERROR] No fue posible determinar una version del chart argo/argo-cd"
  exit 1
fi

if helm show crds argo/argo-cd --version "$ARGOCD_CHART_VERSION" | grep -q 'apiextensions.k8s.io/v1beta1'; then
  echo "[ERROR] El chart argo/argo-cd ${ARGOCD_CHART_VERSION} usa CRDs v1beta1 incompatibles con clusters modernos"
  echo "[ERROR] Define ARGOCD_CHART_VERSION con una version mas reciente"
  exit 1
fi

echo "[INFO] Chart Argo CD seleccionado: $ARGOCD_CHART_VERSION"
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
  --version "$ARGOCD_CHART_VERSION"
  --wait
  --timeout "$ARGOCD_WAIT_TIMEOUT"
)

helm "${HELM_ARGS[@]}"

echo "[INFO] Verificando despliegue de Argo CD"
kubectl -n "$ARGOCD_NAMESPACE" get pods -o wide
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s || true
kubectl -n "$ARGOCD_NAMESPACE" rollout status statefulset/argocd-application-controller --timeout=300s || true

echo "[INFO] Despliegue de Infra Argo CD finalizado"
echo "[INFO] Admin password (si existe):"
kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true
echo ""
gh_group_end
