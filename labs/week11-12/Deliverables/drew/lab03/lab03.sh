# Lab 03 - Pod Security Standards

# Create restricted namespace with security enforcement
kubectl apply -f restricted-namespace.yaml

# Try deploying non-compliant Pod (should be rejected)
kubectl apply -f bad-pod.yaml

# Deploy compliant Pod (should succeed)
kubectl apply -f restricted-pod.yaml
kubectl get pods -n restricted

# View namespace labels
kubectl get namespace restricted --show-labels
