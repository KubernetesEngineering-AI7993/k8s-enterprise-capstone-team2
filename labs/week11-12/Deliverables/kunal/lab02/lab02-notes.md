# Lab 02 - NetworkPolicies Notes

## Policy Design

`default-deny.yaml` applies a namespace-wide deny in `dev`:
- `podSelector: {}` targets all Pods
- `policyTypes: [Ingress, Egress]` blocks all traffic by default

`allow-frontend-backend.yaml` then adds one specific exception:
- destination: Pods with `app=backend`
- source: Pods with `app=frontend` in the same namespace
- port: TCP `8080`

This enforces least-privilege east-west traffic: only the intended app path is allowed.

## Verification Commands

Run:

```bash
bash lab02.sh
```

Equivalent direct checks:

```bash
FRONTEND_POD=$(kubectl get pod -n dev -l app=frontend -o jsonpath='{.items[0].metadata.name}')
INTRUDER_POD=$(kubectl get pod -n dev -l app=intruder -o jsonpath='{.items[0].metadata.name}')
QA_POD=$(kubectl get pod -n qa -l app=qa-client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n dev "$FRONTEND_POD" -- curl -sS -m 5 -o /dev/null -w "%{http_code}\n" http://backend.dev.svc.cluster.local:8080
kubectl exec -n dev "$INTRUDER_POD" -- sh -c 'curl -sS -m 5 -o /dev/null -w "%{http_code}\n" http://backend.dev.svc.cluster.local:8080 || true'
kubectl exec -n qa "$QA_POD" -- sh -c 'curl -sS -m 5 -o /dev/null -w "%{http_code}\n" http://backend.dev.svc.cluster.local:8080 || true'
```

Expected:
- frontend -> backend: `200` (allowed)
- intruder -> backend: timeout or non-`200` (blocked)
- qa-client -> backend: timeout or non-`200` (blocked)
