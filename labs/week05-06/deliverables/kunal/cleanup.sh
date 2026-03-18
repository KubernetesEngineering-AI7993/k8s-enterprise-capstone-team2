set -euo pipefail

echo "=== Lab cleanup: deleting deployments (week05-06) ==="
for dep in app-demo app-env-demo app-vol-demo app-probes rolling-demo probe-demo probe-fail-demo; do
  kubectl delete deployment "$dep" --ignore-not-found --timeout=30s
done

echo ""
echo "=== Deleting ConfigMaps and Secrets (lab02) ==="
kubectl delete configmap app-config --ignore-not-found
kubectl delete secret app-secret --ignore-not-found

echo ""
echo "=== Waiting for resources to terminate... ==="
sleep 10

echo ""
echo "=== Cleanup complete (week05-06) ==="
kubectl get deployments 2>/dev/null || true
kubectl get pods 2>/dev/null || true
kubectl get configmaps 2>/dev/null || true
kubectl get secrets 2>/dev/null || true

