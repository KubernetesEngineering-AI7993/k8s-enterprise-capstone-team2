#!/bin/bash
echo "=== Initial state ==="
sudo kubectl get deployments
sudo kubectl get pods
sudo kubectl get services
sudo kubectl get configmaps
sudo kubectl get secrets
echo "=== Deploy configmap ==="
sudo kubectl apply -f deployment.yaml
echo "=== Inspect configmap ==="
sudo kubectl get configmaps
sudo kubectl describe configmap app-config
echo "=== Deploy secret ==="
sudo kubectl apply -f secret.yaml
echo "=== Inspect secret ==="
sudo kubectl get secrets
sudo kubectl describe secret app-secret
echo "== inject configmap and secret into pods using environment variables =="
sudo kubectl apply -f deploy-env.yaml
echo "== inspect configmap and secret environment variable injection =="
sudo kubectl exec deployment/app-demo -- printenv | grep APP_
echo "== inject configmap and secret into pods using volumes=="
sudo kubectl apply -f deploy-env.yaml
echo "== inspect configmap and secret environment volume injection =="
sudo kubectl exec deployment/app-demo -- ls /etc/config /etc/secrets