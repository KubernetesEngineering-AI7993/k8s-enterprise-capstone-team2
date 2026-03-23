# Lab 01 - GitOps with ArgoCD

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access dashboard (second terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login at https://localhost:8080 with admin / <password>

# Create deployment for ArgoCD to manage
kubectl apply -f deployment.yaml

# Create ArgoCD Application
kubectl apply -f argocd-app.yaml
kubectl get applications -n argocd

# Verify ArgoCD deployed the app
kubectl get deployments
kubectl get pods

# Test auto-sync: change replicas in deployment.yaml, commit, push
# ArgoCD detects git change and scales automatically

# Test self-healing: manually scale down
kubectl scale deployment gitops-demo --replicas=1

# Wait to see if ArgoCD reverts to 3 replicas
kubectl get pods