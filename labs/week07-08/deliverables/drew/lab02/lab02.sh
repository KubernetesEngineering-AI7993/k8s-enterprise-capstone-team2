# Lab 02 - Multi-Container Pods
kubectl apply -f multi-container.yaml
kubectl get pods
kubectl exec sidecar-demo -c main-app -- curl -s localhost
kubectl logs sidecar-demo -c log-sidecar --tail=20
kubectl exec sidecar-demo -c main-app -- ls /var/log/nginx
kubectl exec sidecar-demo -c log-sidecar -- ls /var/log/nginx
kubectl exec sidecar-demo -c log-sidecar -- sh -c "kill 1"
kubectl get pods