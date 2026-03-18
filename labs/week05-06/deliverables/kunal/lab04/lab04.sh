set -euo pipefail

DEPLOYMENT_NAME="app-probes"

echo "=== Lab 04 – Rolling Updates & Rollbacks ==="

echo ""
echo "--- Applying baseline Deployment (probes-and-rolling.yaml) ---"
if [[ -f "./probes-and-rolling.yaml" ]]; then
  kubectl apply -f ./probes-and-rolling.yaml
fi

echo ""
echo "--- Waiting for rollout to complete ---"
kubectl rollout status "deployment/$DEPLOYMENT_NAME" --timeout=180s

echo ""
echo "--- Updating image / applying failing rollout (fail-rollout.yaml) ---"
if [[ -f "./fail-rollout.yaml" ]]; then
  kubectl apply -f ./fail-rollout.yaml
fi

echo ""
echo "--- Watching rollout status ---"
kubectl rollout status "deployment/$DEPLOYMENT_NAME" --timeout=60s || true

echo ""
echo "--- Rolling back failed rollout ---"
kubectl rollout undo "deployment/$DEPLOYMENT_NAME"

echo ""
echo "--- Final Deployment state ---"
kubectl get deployments

