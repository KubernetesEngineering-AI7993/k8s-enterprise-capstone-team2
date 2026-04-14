# Lab 02 - NetworkPolicies

# Create namespace and deploy Pods
kubectl create namespace dev
kubectl apply -f apps.yaml
kubectl get pods -n dev

# Create backend Service
kubectl expose pod backend -n dev --port=80 --name=backend

# Test before policies (both should work)
kubectl exec -n dev frontend -- curl -s --max-time 3 http://backend
kubectl exec -n dev rogue-pod -- curl -s --max-time 3 http://backend

# Apply default-deny (blocks all ingress)
kubectl apply -f default-deny.yaml

# Test after deny (both should timeout)
kubectl exec -n dev frontend -- curl -s --max-time 3 http://backend
kubectl exec -n dev rogue-pod -- curl -s --max-time 3 http://backend

# Allow only frontend to backend
kubectl apply -f allow-frontend-backend.yaml

# Test after allow (frontend works, rogue blocked)
kubectl exec -n dev frontend -- curl -s --max-time 3 http://backend
kubectl exec -n dev rogue-pod -- curl -s --max-time 3 http://backend

# View policies
kubectl get networkpolicies -n dev
kubectl describe networkpolicy allow-frontend-to-backend -n dev
