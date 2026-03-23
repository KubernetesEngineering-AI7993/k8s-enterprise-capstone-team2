# Lab 02 - Secrets Management

# Create secret imperatively 
kubectl create secret generic app-credentials --from-literal=DB_PASSWORD=supersecret123 --from-literal=API_KEY=sk-live-abc123

# Create secret from YAML 
kubectl apply -f secret.yaml

# Create Pod that uses both injection methods
kubectl apply -f secret-pod.yaml
kubectl get pods

# Verify env vars 
kubectl exec secret-demo -- env | findstr "DB_ API_"

# Verify volume mounts 
kubectl exec secret-demo -- ls /etc/secrets
kubectl exec secret-demo -- cat /etc/secrets/DB_USER

# View secrets in cluster
kubectl get secrets
kubectl describe secret app-credentials
kubectl get secret app-credentials -o yaml