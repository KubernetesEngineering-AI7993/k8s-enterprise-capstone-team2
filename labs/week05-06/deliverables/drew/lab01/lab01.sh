# Lab 01 - Deployments & Services
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl get pods
kubectl apply -f service.yaml
kubectl get services
kubectl get endpoints nginx-service
kubectl port-forward service/nginx-service 8080:80
kubectl scale deployment nginx-deployment --replicas=4
kubectl get pods
kubectl get endpoints nginx-service