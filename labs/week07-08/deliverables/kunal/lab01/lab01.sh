set -euo pipefail

RELEASE_NAME="sample-app"
CHART_PATH="./sample-app"

echo "=== Lab 01 – Helm Charts ==="

echo ""
echo "--- Template chart (dry-run) ---"
helm template "$RELEASE_NAME" "$CHART_PATH"

echo ""
echo "--- Install the chart ---"
helm install "$RELEASE_NAME" "$CHART_PATH"

echo ""
echo "--- List releases and pods ---"
helm list
kubectl get pods -l "app=$RELEASE_NAME"
kubectl get svc -l "app=$RELEASE_NAME"

echo ""
echo "--- Upgrade with new values (replicaCount=2, service.type=NodePort, image.tag=1.26) ---"
helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
  --set replicaCount=2 \
  --set service.type=NodePort \
  --set image.tag=1.26

echo ""
echo "--- Wait for rollout ---"
kubectl rollout status "deployment/$RELEASE_NAME" --timeout=120s 2>/dev/null || true
helm list
kubectl get pods -l "app=$RELEASE_NAME"

echo ""
echo "--- Roll back to previous revision ---"
helm rollback "$RELEASE_NAME" 1

echo ""
echo "--- Release history ---"
helm history "$RELEASE_NAME"

echo ""
echo "--- Final state ---"
helm list
kubectl get pods -l "app=$RELEASE_NAME"
