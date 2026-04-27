#!/usr/bin/env bash
# Build warehouse pipeline images with tags matching k8s/base workload manifests.
# Optional: load into a local kind cluster (same names as scripts/cluster-setup.sh).
#
# Usage:
#   ./build-images.sh
#   ./build-images.sh --load-kind
#   LOAD_INTO_KIND=true ./build-images.sh
#
# Env (override tags or kind cluster name):
#   INTAKE_TAG, DETECTION_TAG, DASHBOARD_TAG, KIND_CLUSTER_NAME

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'
info() { echo -e "${CYAN}[build-images]${RESET} $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
die()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INTAKE_TAG="${INTAKE_TAG:-intake-service:v6}"
DETECTION_TAG="${DETECTION_TAG:-detection-service:v1}"
DASHBOARD_TAG="${DASHBOARD_TAG:-dashboard:v4}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-warehouse-cv}"
LOAD_INTO_KIND="${LOAD_INTO_KIND:-false}"

usage() {
  cat <<'EOF'
Usage: build-images.sh [options]

  --load-kind      After building, run kind load docker-image for each tag
                      (cluster: KIND_CLUSTER_NAME, default: warehouse-cv)

  -h, --help       Show this help

Environment:
  INTAKE_TAG, DETECTION_TAG, DASHBOARD_TAG   Image tags (must match k8s manifests)
  KIND_CLUSTER_NAME                          kind cluster name (default: warehouse-cv)
  LOAD_INTO_KIND=true                        Same as --load-kind
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --load-kind) LOAD_INTO_KIND=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

case "${LOAD_INTO_KIND}" in
  true|1|yes|TRUE|True|YES) LOAD_INTO_KIND=true ;;
  *) LOAD_INTO_KIND=false ;;
esac

command -v docker &>/dev/null || die "'docker' not found. Install Docker: https://docs.docker.com/get-docker/"

info "Context: ${SCRIPT_DIR}"
info "Tags: ${INTAKE_TAG}, ${DETECTION_TAG}, ${DASHBOARD_TAG}"

# Intake Dockerfile COPYs images/; fail fast with a clear message.
INTAKE_IMAGES_DIR="${SCRIPT_DIR}/intake-service/images"
if [[ ! -d "${INTAKE_IMAGES_DIR}" ]] || [[ -z "$(find "${INTAKE_IMAGES_DIR}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit 2>/dev/null)" ]]; then
  die "Missing JPEG/PNG files under Docker/intake-service/images/\nSee Docker/README.md (Kaggle dataset copy step)."
fi

info "Building ${INTAKE_TAG}..."
docker build -t "${INTAKE_TAG}" "${SCRIPT_DIR}/intake-service"
ok "Built ${INTAKE_TAG}"

info "Building ${DETECTION_TAG}..."
docker build -t "${DETECTION_TAG}" "${SCRIPT_DIR}/detection-service"
ok "Built ${DETECTION_TAG}"

info "Building ${DASHBOARD_TAG}..."
docker build -t "${DASHBOARD_TAG}" "${SCRIPT_DIR}/dashboard"
ok "Built ${DASHBOARD_TAG}"

if [[ "${LOAD_INTO_KIND}" == "true" ]]; then
  command -v kind &>/dev/null || die "'kind' not found but --load-kind was set. Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"

  if ! kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER_NAME}"; then
    die "kind cluster '${KIND_CLUSTER_NAME}' does not exist.\nCreate it first (e.g. scripts/cluster-setup.sh with CREATE_KIND_IF_MISSING=true) or set KIND_CLUSTER_NAME."
  fi

  for tag in "${INTAKE_TAG}" "${DETECTION_TAG}" "${DASHBOARD_TAG}"; do
    info "Loading ${tag} into kind cluster '${KIND_CLUSTER_NAME}'..."
    kind load docker-image "${tag}" --name "${KIND_CLUSTER_NAME}"
    ok "Loaded ${tag}"
  done
fi

ok "All images built. Deploy manifests use imagePullPolicy: IfNotPresent with these tags."
if [[ "${LOAD_INTO_KIND}" != "true" ]]; then
  info "To load into kind after cluster exists:  ${BASH_SOURCE[0]:-build-images.sh} --load-kind"
  info "Or:  KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME} LOAD_INTO_KIND=true ./build-images.sh"
fi
