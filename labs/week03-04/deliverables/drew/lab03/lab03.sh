#!/usr/bin/env bash
set -e

# Lab 03 – Horizontal Pod Autoscaler (HPA)
# HPA uses metrics to decide when to scale replicas up/down.
# metrics-server must be working .


NS="${NS:-dev}"

# File names
APP_YAML="${APP_YAML:-./lab03/php-apache.yaml}"

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-php-apache}"
HPA_NAME="${HPA_NAME:-php-apache}"
SERVICE_NAME="${SERVICE_NAME:-php-apache}"
POD_LABEL="${POD_LABEL:-run=php-apache}"

LOAD_POD="${LOAD_POD:-load-generator}"

echo " Horizontal Pod Autoscaler (HPA)"

echo "1: Verify metrics are available"
kubectl top nodes
kubectl top pods -n "$NS"


echo "2: Deploy php-apache workload + service"
kubectl apply -n "$NS" -f "$APP_YAML"
kubectl rollout status -n "$NS" deployment/"$DEPLOYMENT_NAME" --timeout=180s
kubectl get deploy,svc,pods -n "$NS" -o wide


echo "3) Create HPA "
# NOTE: --cpu-percent is deprecated; use --cpu "50%" instead.
kubectl autoscale deployment "$DEPLOYMENT_NAME" -n "$NS" --cpu=50% --min=1 --max=10
kubectl get hpa -n "$NS" -o wide
kubectl describe hpa "$HPA_NAME" -n "$NS" || true


echo "4) Generate load (busybox hitting the service in a loop)"
kubectl delete pod "$LOAD_POD" -n "$NS" --ignore-not-found
kubectl run "$LOAD_POD" -n "$NS" --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://$SERVICE_NAME; done"
kubectl wait -n "$NS" --for=condition=Ready pod/"$LOAD_POD" --timeout=120s || true
kubectl get pod "$LOAD_POD" -n "$NS" -o wide


echo "5) Observe scaling (sample outputs)"
sleep 60
kubectl get hpa "$HPA_NAME" -n "$NS" -o wide
kubectl get deploy "$DEPLOYMENT_NAME" -n "$NS" -o wide
kubectl get pods -n "$NS" -l "$POD_LABEL" -o wide

sleep 60
kubectl get hpa "$HPA_NAME" -n "$NS" -o wide
kubectl get deploy "$DEPLOYMENT_NAME" -n "$NS" -o wide
kubectl get pods -n "$NS" -l "$POD_LABEL" -o wide


echo "6) Stop load and observe scale down"
kubectl delete pod "$LOAD_POD" -n "$NS" --ignore-not-found
sleep 90
kubectl get hpa "$HPA_NAME" -n "$NS" -o wide
kubectl get deploy "$DEPLOYMENT_NAME" -n "$NS" -o wide
kubectl get pods -n "$NS" -l "$POD_LABEL" -o wide
