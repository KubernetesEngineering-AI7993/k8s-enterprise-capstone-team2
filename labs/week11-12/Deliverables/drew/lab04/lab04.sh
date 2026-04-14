# Lab 04 - Observability and Incident Simulation

# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set prometheus.prometheusSpec.resources.requests.memory=256Mi --set prometheus.prometheusSpec.resources.requests.cpu=100m
kubectl get pods -n monitoring

# Get Grafana password
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# Access Grafana (run in second terminal)
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# Open http://localhost:3000, login: admin / <password>

# Deploy test app
kubectl apply -f stress-app.yaml
kubectl get pods

# Simulate incident (memory bomb)
kubectl apply -f memory-bomb.yaml

# Observe the incident
kubectl get pods
kubectl describe pod memory-bomb

# Check Grafana dashboard: Kubernetes / Compute Resources / Pod
# Select memory-bomb pod, observe memory spike to limit

# Clean up
kubectl delete pod memory-bomb
