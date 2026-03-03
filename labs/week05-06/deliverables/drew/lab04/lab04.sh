# Lab 04 - Rolling Updates & Rollbacks
kubectl apply -f probes-and-rolling.yaml
kubectl rollout status deployment/rolling-demo
kubectl set image deployment/rolling-demo nginx=nginx:1.27
kubectl rollout status deployment/rolling-demo
kubectl get pods -w
kubectl set image deployment/rolling-demo nginx=nginx:1.26
kubectl rollout history deployment/rolling-demo
kubectl apply -f fail-rollout.yaml
kubectl get pods
kubectl rollout status deployment/rolling-demo
kubectl rollout undo deployment/rolling-demo
kubectl rollout status deployment/rolling-demo
kubectl get pods