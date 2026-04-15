#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-week11-12-labs}"
KIND_CONFIG="${KIND_CONFIG:-$BASE_DIR/kind-cluster.yaml}"
LOG_DIR="$BASE_DIR/output"
mkdir -p "$LOG_DIR"
LAB_TIMEOUT_SECONDS="${LAB_TIMEOUT_SECONDS:-1200}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/all-labs-$TIMESTAMP.txt"

# Tee the entire script output to a single text log.
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Week11-12 Labs Runner ==="
echo "Base directory: $BASE_DIR"
echo "Cluster name:   $CLUSTER_NAME"
echo "Kind config:    $KIND_CONFIG"
echo "Lab timeout:    ${LAB_TIMEOUT_SECONDS}s each"
echo "Log file:       $LOG_FILE"
echo

for cmd in kind kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is required but not installed or not in PATH."
    exit 1
  fi
done

create_kind_cluster() {
  local create_log
  local retry_log
  local create_output
  local retry_output
  create_log="$(mktemp)"
  retry_log="$(mktemp)"

  echo "Creating Kind cluster '$CLUSTER_NAME'..."
  if kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG" 2>&1 | tee "$create_log"; then
    rm -f "$create_log" "$retry_log"
    return 0
  fi

  create_output="$(<"$create_log")"
  if [[ "$create_output" == *"port is already allocated"* ]] || [[ "$create_output" == *"Bind for "* && "$create_output" == *" failed"* ]]; then
    local fallback_config
    local compat_config
    local compat_image
    fallback_config="$LOG_DIR/kind-cluster-no-hostports.yaml"
    compat_config="$LOG_DIR/kind-cluster-compat-image.yaml"
    compat_image="${KIND_NODE_IMAGE:-kindest/node:v1.34.6}"
    cat > "$fallback_config" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
  - role: worker
    labels:
      GPU: "true"
  - role: worker
EOF
    echo
    echo "Host port mapping conflict detected. Retrying without host port mappings..."
    echo "Fallback config: $fallback_config"
    if kind create cluster --name "$CLUSTER_NAME" --config "$fallback_config" 2>&1 | tee "$retry_log"; then
      rm -f "$create_log" "$retry_log"
      return 0
    fi

    retry_output="$(<"$retry_log")"
    if [[ "$retry_output" == *"could not find a log line that matches"* ]]; then
      cat > "$compat_config" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
  - role: control-plane
    image: $compat_image
    labels:
      ingress-ready: "true"
  - role: worker
    image: $compat_image
    labels:
      GPU: "true"
  - role: worker
    image: $compat_image
EOF
      echo
      echo "Kind node boot detection failed. Retrying with compatibility node image..."
      echo "Compatibility image: $compat_image"
      echo "Compatibility config: $compat_config"
      kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
      if kind create cluster --name "$CLUSTER_NAME" --config "$compat_config"; then
        rm -f "$create_log" "$retry_log"
        return 0
      fi
    fi
  fi

  echo "ERROR: Kind cluster creation failed (non-port related)."
  rm -f "$create_log" "$retry_log"
  return 1
}

if kind get clusters | grep -Fx "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo "Kind cluster '$CLUSTER_NAME' already exists. Reusing it."
else
  create_kind_cluster
fi

kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null
echo "Using kubectl context: kind-$CLUSTER_NAME"
echo

run_lab() {
  local lab_name="$1"
  local lab_script="$2"
  local exit_code=0
  echo "----- START $lab_name -----"
  if timeout "${LAB_TIMEOUT_SECONDS}s" bash "$lab_script"; then
    echo "----- END $lab_name (success) -----"
  else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      echo "----- END $lab_name (timeout after ${LAB_TIMEOUT_SECONDS}s) -----"
    else
      echo "----- END $lab_name (failed with exit code $exit_code) -----"
    fi
  fi
  echo
  return $exit_code
}

lab_failures=0
failed_labs=()

if ! run_lab "LAB01" "$BASE_DIR/lab01/lab01.sh"; then
  ((lab_failures+=1))
  failed_labs+=("LAB01")
fi
if ! run_lab "LAB02" "$BASE_DIR/lab02/lab02.sh"; then
  ((lab_failures+=1))
  failed_labs+=("LAB02")
fi
if ! run_lab "LAB03" "$BASE_DIR/lab03/lab03.sh"; then
  ((lab_failures+=1))
  failed_labs+=("LAB03")
fi
if ! run_lab "LAB04" "$BASE_DIR/lab04/lab04.sh"; then
  ((lab_failures+=1))
  failed_labs+=("LAB04")
fi

if [[ $lab_failures -eq 0 ]]; then
  echo "All labs completed successfully."
else
  echo "Completed with failures in: ${failed_labs[*]}"
fi
echo "Output captured in: $LOG_FILE"

if [[ $lab_failures -ne 0 ]]; then
  exit 1
fi
