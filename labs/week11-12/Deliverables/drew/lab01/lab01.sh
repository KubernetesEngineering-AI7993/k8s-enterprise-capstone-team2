# Lab 01 - RBAC & ServiceAccounts

# Create dev namespace
kubectl create namespace dev

# Apply RBAC resources
kubectl apply -f serviceaccount.yaml
kubectl apply -f readonly-role.yaml
kubectl apply -f readonly-rolebinding.yaml

# Deploy test pods
kubectl apply -f test-pod.yaml
kubectl get pods -n dev

# Verify read access (should succeed)
kubectl exec -n dev rbac-test -- kubectl get pods -n dev

# Verify delete is blocked (should fail with Forbidden)
kubectl exec -n dev rbac-test -- kubectl delete pod dummy-pod -n dev

# View RBAC resources
kubectl get serviceaccount -n dev
kubectl get role -n dev
kubectl get rolebinding -n dev
kubectl describe role pod-reader -n dev
kubectl describe rolebinding read-pods-binding -n dev
