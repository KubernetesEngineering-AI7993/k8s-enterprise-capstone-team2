#!/usr/bin/env bash
set -e

# Lab 01 – Resource Requests & Limits
# "Requests" tell the scheduler how much CPU/memory to reserve when picking a node.
# "Limits" are the hard ceiling. If a container uses too much memory, it can get OOMKilled.
# metrics-server should already be installed

NS="${NS:-dev}"

# File names
NO_LIMITS_YAML="${NO_LIMITS_YAML:-./lab01/deployment-no-limits.yaml}"
WITH_LIMITS_YAML="${WITH_LIMITS_YAML:-./lab01/deployment-with-limits.yaml}"
OOM_YAML="${OOM_YAML:-./lab01/oom-demo.yaml}"

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-resource-demo}"
POD_SELECTOR="${POD_SELECTOR:-app=resource-demo}"
OOM_POD_NAME="${OOM_POD_NAME:-oom-demo}"

echo "1: Resource Requests & Limits"

echo "Deploy workload w/o requests/limits ---"
kubectl apply -n "$NS" -f "$NO_LIMITS_YAML"
kubectl rollout status -n "$NS" deployment/"$DEPLOYMENT_NAME" --timeout=120s || true
kubectl get deploy,pods -n "$NS" -o wide

echo "2: Observe usage with kubectl top"
kubectl top nodes || true
kubectl top pods -n "$NS" || true

echo "3: Apply updated deployment w/ requests/limits"
# NOTE: WITH_LIMITS_YAML is the updated version that adds requests/limits in the container spec.
kubectl apply -n "$NS" -f "$WITH_LIMITS_YAML"
kubectl rollout status -n "$NS" deployment/"$DEPLOYMENT_NAME" --timeout=120s || true
kubectl get pods -n "$NS" -l "$POD_SELECTOR" -o wide
kubectl describe pod -n "$NS" -l "$POD_SELECTOR" || true

echo "4: Observe usage"
kubectl top pods -n "$NS" || true

echo "5 Trigger an OOMKilled scenario"
# The OOM YAML should set a low memory limit and then allocate more than that.
kubectl delete pod "$OOM_POD_NAME" -n "$NS" --ignore-not-found
kubectl apply -n "$NS" -f "$OOM_YAML"
sleep 10
kubectl get pod "$OOM_POD_NAME" -n "$NS" -o wide
kubectl describe pod "$OOM_POD_NAME" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
