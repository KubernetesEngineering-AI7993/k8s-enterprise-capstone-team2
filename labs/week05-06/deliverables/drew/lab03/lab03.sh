# Lab 03 - Liveness & Readiness Probes
kubectl apply -f add_liveness.yaml
kubectl get pods
kubectl describe pod -l app=probe-demo
kubectl apply -f add_liveness_with_failure.yaml
kubectl get pods
kubectl describe pod -l app=probe-fail
kubectl apply -f add_liveness_fixed.yaml
kubectl get pods