#!/usr/bin/env bash
set -e

# Lab 02 – Scheduling, Taints & Tolerations
# Taint on a node = "Pods cannot schedule here unless they have permission."
# Toleration on a pod = the permission slip.
# nodeSelector = "Only schedule me onto nodes with this label."


cd "$(dirname "$0")"

NS="${NS:-dev}"

# File names
NO_TOL_YAML="${NO_TOL_YAML:-./lab02/pod-no-toleration.yaml}"
WITH_TOL_YAML="${WITH_TOL_YAML:-./lab02/pod-with-toleration.yaml}"
BAD_SELECTOR_YAML="${BAD_SELECTOR_YAML:-./lab02/pod-bad-nodeselector.yaml}"

# Node name
TAINT_NODE="${TAINT_NODE:-cka-wk34-worker}"

# Pod names used by your YAMLs
NO_TOL_POD="${NO_TOL_POD:-taint-test-no}"
WITH_TOL_POD="${WITH_TOL_POD:-taint-test-yes}"
BAD_SELECTOR_POD="${BAD_SELECTOR_POD:-selector-bad}"

echo "Scheduling, Taints & Tolerations"

echo "1: Label the node so nodeSelector can target it"
kubectl get nodes -o wide
kubectl label node "$TAINT_NODE" role=worker --overwrite
kubectl get nodes --show-labels


echo "2: Taint the node (NoSchedule)"
# This blocks pods unless they have a toleration for this taint.
kubectl taint node "$TAINT_NODE" dedicated=lab:NoSchedule --overwrite
kubectl describe node "$TAINT_NODE" || true


echo "3: Deploy pod w/o toleration"
kubectl delete pod "$NO_TOL_POD" -n "$NS" --ignore-not-found
kubectl apply -n "$NS" -f "$NO_TOL_YAML"
sleep 10
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$NO_TOL_POD" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete pod "$NO_TOL_POD" -n "$NS" --ignore-not-found


echo "4: Deploy pod w/ toleration"
# NOTE: WITH_TOL_YAML is the fixed version where tolerations were added.
kubectl delete pod "$WITH_TOL_POD" -n "$NS" --ignore-not-found
kubectl apply -n "$NS" -f "$WITH_TOL_YAML"
kubectl wait -n "$NS" --for=condition=Ready pod/"$WITH_TOL_POD" --timeout=120s || true
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$WITH_TOL_POD" -n "$NS" || true
kubectl delete pod "$WITH_TOL_POD" -n "$NS" --ignore-not-found


echo "5: nodeSelector mismatch"
kubectl delete pod "$BAD_SELECTOR_POD" -n "$NS" --ignore-not-found
kubectl apply -n "$NS" -f "$BAD_SELECTOR_YAML"
sleep 8
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$BAD_SELECTOR_POD" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete pod "$BAD_SELECTOR_POD" -n "$NS" --ignore-not-found


