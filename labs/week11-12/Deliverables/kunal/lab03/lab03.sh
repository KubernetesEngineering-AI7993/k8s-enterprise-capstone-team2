#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="pss-lab"

echo "=== Lab 03 - Pod Security Standards ==="
echo "Creating namespace and enforcing restricted Pod Security profile..."
kubectl create namespace "$NAMESPACE" >/dev/null 2>&1 || true
kubectl label namespace "$NAMESPACE" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite

echo "Attempting to create non-compliant Pod (expected rejection)..."
kubectl apply -f "$LAB_DIR/non-compliant-pod.yaml" || true

echo "Creating compliant restricted Pod..."
kubectl apply -f "$LAB_DIR/restricted-pod.yaml"
kubectl wait --for=condition=Ready pod/restricted-pod -n "$NAMESPACE" --timeout=180s

echo "Current pods in $NAMESPACE:"
kubectl get pods -n "$NAMESPACE" -o wide
