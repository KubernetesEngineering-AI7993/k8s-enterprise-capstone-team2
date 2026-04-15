#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="observability-lab"

echo "=== Lab 04 - Observability & Incident Simulation ==="
echo "Applying observability lab workload..."
kubectl apply -f "$LAB_DIR/observability-workload.yaml"

echo "Waiting for podinfo deployment..."
kubectl wait --for=condition=Available deployment/podinfo -n "$NAMESPACE" --timeout=180s

echo "Smoke test podinfo endpoint..."
kubectl run curl-check -n "$NAMESPACE" --rm -i --restart=Never --image=curlimages/curl:8.7.1 -- \
  curl -sS http://podinfo.observability-lab.svc.cluster.local:9898/ </dev/null | head -c 160 || true
echo

echo "Triggering incident: scale cpu-burner to 2 replicas..."
kubectl scale deployment/cpu-burner -n "$NAMESPACE" --replicas=2
kubectl wait --for=condition=Available deployment/cpu-burner -n "$NAMESPACE" --timeout=180s || true

cat <<'EOF'

Next steps:
1) Ensure your Prometheus stack includes the scrape values from:
   prometheus-scrape-config.yaml
2) Import grafana-dashboard.json in Grafana.
3) Observe CPU spike for pods in namespace observability-lab.
4) Resolve incident:
   kubectl scale deployment/cpu-burner -n observability-lab --replicas=0
EOF
