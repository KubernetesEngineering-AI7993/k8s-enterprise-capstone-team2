# Lab 02 - ConfigMaps & Secrets
kubectl apply -f configmap.yaml
kubectl get configmaps
kubectl describe configmap app-config
kubectl apply -f secret.yaml
kubectl get secrets
kubectl describe secret app-secret
kubectl apply -f deploy-env.yaml
kubectl exec deploy/app-env-demo -- env
kubectl delete deployment app-env-demo
kubectl apply -f deploy_vol.yaml
kubectl exec deploy/app-vol-demo -- ls /etc/config
kubectl exec deploy/app-vol-demo -- cat /etc/config/APP_ENV
kubectl exec deploy/app-vol-demo -- ls /etc/secret
kubectl exec deploy/app-vol-demo -- cat /etc/secret/DB_PASSWORD