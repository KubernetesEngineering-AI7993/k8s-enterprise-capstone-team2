# Lab 02 – Scheduling, Taints & Tolerations 

## Goal
Practice controlling where pods can and cannot run using:
- node labels + nodeSelector
- taints (node repels pods)
- tolerations (pod permission slip)

## What I did
1) Labeled a worker node.
2) Added a NoSchedule taint to the node.
3) Deployed a pod with nodeSelector pointing at the worker but without toleration:
   - Result: pod stayed Pending.
4) Deployed a pod with the same nodeSelector and a toleration:
   - Result: pod scheduled and ran.

## What it means
- nodeSelector is a pod rule: “only run me on nodes with this label.”
- taint is a node rule: “pods can’t run here unless they tolerate me.”
- toleration is the pod’s matching rule: “I’m allowed on that tainted node.”

## What I looked for as proof
- Pending pod + `kubectl describe pod` shows events like “untolerated taint.”
- Running pod shows it scheduled onto the intended node in `kubectl get pods -o wide`.

## Key takeaway
Scheduling is just rule matching. If any required rule fails, the scheduler cannot place the pod → it stays Pending.
