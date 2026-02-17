echo "=== Initial state: deployments ==="
kubectl get deployments

echo ""
echo "=== Deploying workload WITHOUT resource limits (no-resource-limits.yaml) ==="
kubectl apply -f ./no-resource-limits.yaml
kubectl wait --for=condition=available --timeout=60s deployment/resource-demo

echo ""
echo "=== Deployments after applying no-resource-limits ==="
kubectl get deployments

echo ""
echo "=== Pods (no resource limits) ==="
kubectl get pods

# If Metrics Server is not installed
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo ""
echo "=== Resource usage: top pods ==="
kubectl top pods

echo ""
echo "=== Resource usage: top nodes ==="
kubectl top nodes

echo ""
echo "=== Deleting deployment, then deploying WITH resource limits (resource-limits.yaml) ==="
kubectl delete deployment resource-demo --ignore-not-found
kubectl wait --for=delete deployment/resource-demo --timeout=60s 2>/dev/null || true

kubectl apply -f ./resource-limits.yaml
kubectl wait --for=condition=available --timeout=60s deployment/resource-demo

echo ""
echo "=== Pods (with resource limits) ==="
kubectl get pods

echo ""
echo "=== Resource usage with limits: top pods ==="
kubectl top pods

echo ""
echo "=== Pod details (resource limits) ==="
kubectl describe pod

echo ""
echo "=== Deleting deployment, then deploying OOMKilled scenario (oomkilled.yaml) ==="
kubectl delete deployment resource-demo --ignore-not-found
kubectl wait --for=delete deployment/resource-demo --timeout=60s 2>/dev/null || true

kubectl apply -f ./oomkilled.yaml
kubectl wait --for=condition=available --timeout=60s deployment/resource-demo

echo ""
echo "=== Pods (OOMKilled scenario) ==="
kubectl get pods

echo ""
echo "=== Resource usage: top pods (OOM scenario) ==="
kubectl top pods

echo ""
echo "=== Pod details (OOM scenario) ==="
kubectl describe pod

echo ""
echo "=== Triggering OOM: running memory-heavy command in pod ==="
kubectl wait --for=condition=ready pod -l app=resource-demo --timeout=60s
kubectl exec $(kubectl get pod -l app=resource-demo -o jsonpath='{.items[0].metadata.name}') -- /bin/bash -c "tail /dev/zero"

echo ""
echo "=== Pod YAML: OOM-related fields ==="
sleep 5
kubectl get pod --output=yaml | grep OOM