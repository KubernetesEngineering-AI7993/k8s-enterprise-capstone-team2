echo "=== Current nodes ==="
kubectl get nodes

echo ""
echo "=== Tainting node test-k8s-worker2 (dedicated=ops:NoSchedule) ==="
kubectl taint nodes test-k8s-worker2 dedicated=ops:NoSchedule

echo ""
echo "=== Labeling node test-k8s-worker2 (tainttest=target) ==="
kubectl label nodes test-k8s-worker2 tainttest=target

echo ""
echo "=== Node details: test-k8s-worker2 (taints and labels) ==="
kubectl describe node test-k8s-worker2

echo ""
echo "=== Deploying test-pod with nodeSelector (no toleration – observe scheduling) ==="
kubectl run test-pod --image=nginx --overrides='{"spec":{"nodeSelector":{"test": "target"}}}'
sleep 5

echo ""
echo "=== Pods ==="
kubectl get pods

echo ""
echo "=== Pod details: test-pod ==="
kubectl describe pod test-pod

echo ""
echo "=== Deploying workload with tolerations (taints-tolerations.yaml) ==="
kubectl apply -f ./taints-tolerations.yaml
kubectl wait --for=condition=ready pod/toleration-demo --timeout=60s

echo ""
echo "=== Pods with node placement (-o wide) ==="
kubectl get pods -o wide

echo ""
echo "=== Pod details: toleration-demo ==="
kubectl describe pod toleration-demo
