set -euo pipefail

DEPLOY_NAME="rolling-demo"

echo "=== Lab 04 – Deployment Strategies ==="

echo ""
echo "--- Applying baseline Deployment (rolling update strategy) ---"
kubectl apply -f ./deployment-strategy.yaml

echo ""
echo "--- Waiting for rollout ---"
kubectl rollout status "deployment/$DEPLOY_NAME" --timeout=120s

echo ""
echo "--- Current state ---"
kubectl get deployment "$DEPLOY_NAME"
kubectl get pods -l app="$DEPLOY_NAME" -o wide

echo ""
echo "--- Simulating bad release (apply bad-release.yaml – invalid image) ---"
kubectl apply -f ./bad-release.yaml

echo ""
echo "--- Rollout status (may block or show progress; old pods stay until new are Ready) ---"
kubectl rollout status "deployment/$DEPLOY_NAME" --timeout=30s 2>/dev/null || true

echo ""
echo "--- Pods (new replicas may be ImagePullBackOff) ---"
kubectl get pods -l app="$DEPLOY_NAME" -o wide

echo ""
echo "--- Roll back to previous revision ---"
kubectl rollout undo "deployment/$DEPLOY_NAME"

echo ""
echo "--- Wait for rollback rollout ---"
kubectl rollout status "deployment/$DEPLOY_NAME" --timeout=120s

echo ""
echo "--- Deployment history ---"
kubectl rollout history "deployment/$DEPLOY_NAME"

echo ""
echo "--- Final state ---"
kubectl get deployment "$DEPLOY_NAME"
kubectl get pods -l app="$DEPLOY_NAME"
