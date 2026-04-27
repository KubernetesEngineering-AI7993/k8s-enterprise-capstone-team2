# Kubernetes NetworkPolicy — Design Notes & Verification

> **Scope:** `dev` namespace · default-deny all · frontend → backend on TCP 8080

---

## Architecture

```
┌─────────────────────────────── dev namespace ───────────────────────────────┐
│                                                                               │
│   ┌──────────────┐   TCP 8080 ✅    ┌──────────────┐                        │
│   │   frontend   │ ──────────────►  │   backend    │                        │
│   │  app=frontend│                  │  app=backend │                        │
│   └──────────────┘                  └──────────────┘                        │
│                                            ▲                                 │
│   ┌──────────────┐   TCP 8080 ❌           │                                 │
│   │  other-pod   │ ──────────────X         │ blocked by default-deny         │
│   │   app=other  │                         │                                 │
│   └──────────────┘                                                           │
│                                                                               │
│   ┌──────────────────────────────────────────────────────┐                  │
│   │  other-namespace Pod → backend TCP 8080  ❌ blocked  │                  │
│   └──────────────────────────────────────────────────────┘                  │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## Apply Order

```bash
# 1. Create the namespace (if it doesn't exist)
kubectl create namespace dev

# 2. Label kube-system so the DNS egress namespaceSelector matches
kubectl label namespace kube-system kubernetes.io/metadata.name=kube-system --overwrite

# 3. Apply policies — default-deny first, then allow rules
kubectl apply -f default-deny.yaml
kubectl apply -f allow-frontend-backend.yaml

# 4. Deploy test pods
kubectl apply -f test-pods.yaml

# 5. Wait for all pods to be Running
kubectl get pods -n dev -w
```

---

## Verification — `kubectl exec` Curl Tests

Get the backend Pod IP first:

```bash
BACKEND_IP=$(kubectl get pod backend -n dev -o jsonpath='{.status.podIP}')
echo "Backend IP: $BACKEND_IP"
```

---

### ✅ Test 1 — Frontend → Backend (should SUCCEED)

```bash
kubectl exec -n dev frontend -- \
  curl -s --max-time 5 http://$BACKEND_IP:8080
```

**Expected output:**

```
hello from backend
```

**What's happening:** The frontend Pod has label `app=frontend`, which matches the `podSelector` in both `allow-frontend-egress-to-backend` (egress on TCP 8080) and `allow-frontend-to-backend` (ingress into backend on TCP 8080). Both sides of the connection are explicitly allowed — the packet is permitted.

---

### ❌ Test 2 — Other Pod → Backend (should FAIL)

```bash
kubectl exec -n dev other-pod -- \
  curl -s --max-time 5 http://$BACKEND_IP:8080
```

**Expected output:**

```
curl: (28) Connection timed out after 5000 milliseconds
```

**What's happening:** `other-pod` has label `app=other`, which matches no `from` selector in any allow policy. The `default-deny-all` policy applies and drops the packet silently (no RST, hence timeout rather than connection refused).

---

### ❌ Test 3 — Other Pod → Backend on a different port (should FAIL)

```bash
kubectl exec -n dev other-pod -- \
  curl -s --max-time 5 http://$BACKEND_IP:9090
```

**Expected output:**

```
curl: (28) Connection timed out after 5000 milliseconds
```

**What's happening:** Even if `other-pod` had `app=frontend`, port 9090 is not in any allow rule. The port restriction in `allow-frontend-to-backend` is `8080` only.

---

### ❌ Test 4 — Frontend → Backend on wrong port (should FAIL)

```bash
kubectl exec -n dev frontend -- \
  curl -s --max-time 5 http://$BACKEND_IP:9090
```

**Expected output:**

```
curl: (28) Connection timed out after 5000 milliseconds
```

**What's happening:** The frontend egress policy only opens TCP 8080 to backend. Port 9090 egress from frontend has no matching allow rule, so the packet is dropped by `default-deny-all`.

---

### ❌ Test 5 — Cross-namespace Pod → Backend (should FAIL)

```bash
# Run a curl pod in the default namespace
kubectl run cross-ns-test --image=curlimages/curl --restart=Never \
  -n default -- sleep 3600

kubectl exec -n default cross-ns-test -- \
  curl -s --max-time 5 http://$BACKEND_IP:8080
```

**Expected output:**

```
curl: (28) Connection timed out after 5000 milliseconds
```

**What's happening:** The `allow-frontend-to-backend` ingress rule uses a bare `podSelector` with no `namespaceSelector`. A bare `podSelector` in NetworkPolicy only matches Pods **within the same namespace**. Pods from `default` or any other namespace are blocked regardless of their labels.

---

### ✅ Test 6 — DNS resolution still works from frontend (sanity check)

```bash
kubectl exec -n dev frontend -- \
  nslookup kubernetes.default.svc.cluster.local
```

**Expected output:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.96.0.1
```

**What's happening:** The `allow-dns-egress` policy re-opens UDP/TCP 53 toward `kube-system` for all Pods in `dev`. Without this, `default-deny-all` would block CoreDNS queries and all hostname-based connections would fail with "could not resolve host".

---

## Policy Design Notes

### 1. Default-deny covers both Ingress and Egress

Many guides only default-deny Ingress. Denying Egress too is important because:

- Prevents compromised Pods from making outbound calls (data exfiltration, C2 callbacks).
- Prevents lateral movement via outbound connections to other services.
- Forces every egress path to be explicitly documented in policy.

The trade-off is that DNS must be explicitly re-opened (Policy 3 in `allow-frontend-backend.yaml`), which is a common gotcha.

### 2. Both sides of the connection must be allowed

With a default-deny-all on both Ingress and Egress, a connection between frontend and backend requires **two** policies:

| Policy | Governs | Rule |
|---|---|---|
| `allow-frontend-to-backend` | backend Pod (Ingress) | Accept inbound from `app=frontend` on 8080 |
| `allow-frontend-egress-to-backend` | frontend Pod (Egress) | Allow outbound to `app=backend` on 8080 |

Omitting either one causes the connection to fail even though the other side is open.

### 3. `podSelector: {}` matches everything in the namespace

In `default-deny-all`, an empty `podSelector: {}` is intentional — it matches **every Pod** in the namespace, not just unlabelled ones. This is the standard pattern for a namespace-wide default deny.

### 4. Cross-namespace traffic is blocked by default with a bare `podSelector`

A `from.podSelector` without a companion `namespaceSelector` only matches Pods in the **same namespace** as the policy. This is the desired behavior here — no explicit cross-namespace block is needed. To allow cross-namespace traffic you would need:

```yaml
from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: other-ns
    podSelector:
      matchLabels:
        app: frontend
```

Note: when `namespaceSelector` and `podSelector` are under the same `-` list item, they form an AND condition. Separate `-` items form an OR.

### 5. Port restriction limits the attack surface

The port restriction `port: 8080` in both the ingress and egress rules ensures:

- Backend cannot be reached on any other port (e.g., a debug endpoint on 9090 or a metrics port on 2112).
- Frontend cannot make outbound calls on any port except 8080 to backend.

### 6. Summary table

| Source | Destination | Port | Result | Reason |
|---|---|---|---|---|
| `app=frontend` (dev) | `app=backend` (dev) | 8080 | ✅ Allowed | Matched by both allow policies |
| `app=frontend` (dev) | `app=backend` (dev) | 9090 | ❌ Blocked | Port not in egress rule |
| `app=other` (dev) | `app=backend` (dev) | 8080 | ❌ Blocked | Label not in ingress allow rule |
| `app=other` (dev) | `app=backend` (dev) | any | ❌ Blocked | default-deny-all; no allow rule |
| Any Pod (default ns) | `app=backend` (dev) | 8080 | ❌ Blocked | No namespaceSelector in allow rule |
| Any Pod (dev) | kube-dns (kube-system) | 53 | ✅ Allowed | allow-dns-egress policy |
| Any Pod (dev) | Anything else | any | ❌ Blocked | default-deny-all egress |
