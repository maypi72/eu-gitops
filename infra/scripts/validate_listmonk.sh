#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${CHART_DIR:-${SCRIPT_DIR}/../charts/listmonk}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/listmonk-validation}"

BASE_VALUES="${CHART_DIR}/values.yaml"
DEV_VALUES="${CHART_DIR}/values-dev.yaml"
PRO_VALUES="${CHART_DIR}/values-pro.yaml"

log() {
  echo "[INFO] $*"
}

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

command -v helm >/dev/null 2>&1 || fail "helm no esta instalado"
[ -d "$CHART_DIR" ] || fail "No existe el chart: $CHART_DIR"
[ -f "$BASE_VALUES" ] || fail "No existe values base: $BASE_VALUES"
[ -f "$DEV_VALUES" ] || fail "No existe values dev: $DEV_VALUES"
[ -f "$PRO_VALUES" ] || fail "No existe values pro: $PRO_VALUES"

mkdir -p "$OUTPUT_DIR"

log "Actualizando dependencias Helm del chart"
helm dependency update "$CHART_DIR"

log "Lint entorno dev"
helm lint "$CHART_DIR" -f "$BASE_VALUES" -f "$DEV_VALUES"

log "Lint entorno pro"
helm lint "$CHART_DIR" -f "$BASE_VALUES" -f "$PRO_VALUES"

log "Renderizando manifests dev"
helm template listmonk-dev "$CHART_DIR" -f "$BASE_VALUES" -f "$DEV_VALUES" >"${OUTPUT_DIR}/listmonk-dev.yaml"

log "Renderizando manifests pro"
helm template listmonk-pro "$CHART_DIR" -f "$BASE_VALUES" -f "$PRO_VALUES" >"${OUTPUT_DIR}/listmonk-pro.yaml"

log "Resumen de recursos clave en dev"
grep -E "^kind: (Rollout|Ingress|Certificate|Issuer|Service)$" "${OUTPUT_DIR}/listmonk-dev.yaml" | sort | uniq -c || true

log "Resumen de recursos clave en pro"
grep -E "^kind: (Rollout|Ingress|Certificate|Issuer|Service)$" "${OUTPUT_DIR}/listmonk-pro.yaml" | sort | uniq -c || true

log "Validacion completada"
log "Salida dev: ${OUTPUT_DIR}/listmonk-dev.yaml"
log "Salida pro: ${OUTPUT_DIR}/listmonk-pro.yaml"
