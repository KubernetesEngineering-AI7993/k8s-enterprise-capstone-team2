set -euo pipefail

echo "=== Lab 02 – ConfigMaps & Secrets ==="

echo ""
echo "--- Applying ConfigMap (configmap.yaml) ---"
kubectl apply -f ./configmap.yaml

echo ""
echo "--- Applying Secret (secret.yaml) ---"
kubectl apply -f ./secret.yaml

echo ""
echo "--- Verifying ConfigMaps ---"
kubectl get configmaps

echo ""
echo "--- Verifying Secrets ---"
kubectl get secrets

echo ""
echo "--- Applying Deployment that uses ConfigMap & Secret (deploy-env.yaml / deploy_vol.yaml) ---"
if [[ -f "./deploy-env.yaml" ]]; then
  kubectl apply -f ./deploy-env.yaml
fi
if [[ -f "./deploy_vol.yaml" ]]; then
  kubectl apply -f ./deploy_vol.yaml
fi

echo ""
echo "--- Pods ---"
kubectl get pods

