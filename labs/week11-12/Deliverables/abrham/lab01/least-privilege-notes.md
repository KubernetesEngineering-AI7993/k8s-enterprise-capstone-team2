# Kubernetes Least-Privilege RBAC — Design Notes

> **Scope:** `dev` namespace · `readonly-app-sa` ServiceAccount · `pod-reader` Role

---

## Overview

The RBAC setup follows the principle of **least privilege**: every permission not explicitly required is denied. Three axes of restriction are applied simultaneously — namespace, resource type, and verb — so that a compromised workload has the smallest possible blast radius.

---

## 1. Role vs ClusterRole — Namespace Scoping

A **`Role`** (not a `ClusterRole`) is used deliberately.

| Object | Scope |
|---|---|
| `Role` | Single namespace only |
| `ClusterRole` | All namespaces cluster-wide |

Using a `Role` means `readonly-app-sa` has **zero permissions** in `default`, `kube-system`, or any other namespace — even if an attacker somehow reuses or clones the binding. The namespace boundary is enforced at the Kubernetes API level, not by application logic.

---

## 2. Resource Scoping — Pods Only

The rule targets only the `""` (core) API group and only the `pods` resource.

```yaml
apiGroups: [""]
resources: ["pods"]
```

This means the SA cannot touch any of the following, even with read verbs:

| Resource | Risk if accessible |
|---|---|
| `secrets` | Credential leakage (tokens, passwords, TLS keys) |
| `configmaps` | Application config, sometimes contains sensitive data |
| `deployments` / `replicasets` | Workload control — scale, rollout, image swap |
| `services` / `ingresses` | Network exposure changes |
| `persistentvolumeclaims` | Storage manipulation |
| `serviceaccounts` | Impersonation of other identities |
| `roles` / `rolebindings` | Privilege escalation |

---

## 3. Verb Scoping — `get` and `list` Only

Only two verbs are granted. Every other verb is denied by default.

| Verb | Granted | Reason for denial |
|---|---|---|
| `get` | ✅ Yes | Core read use-case |
| `list` | ✅ Yes | Core read use-case |
| `watch` | ❌ No | Streams real-time events; reconnaissance risk |
| `create` | ❌ No | Spin up arbitrary workloads |
| `update` | ❌ No | Mutate running pod specs (env vars, volumes, image) |
| `patch` | ❌ No | Targeted mutation; harder to audit than update |
| `delete` | ❌ No | Disrupt services, cover tracks, cause data loss |
| `exec` | ❌ No | Open a shell into any pod — container escape risk |
| `portforward` | ❌ No | Tunnel into cluster-internal services |
| `proxy` | ❌ No | Route traffic through a pod to internal endpoints |

> **Note:** `watch` is commonly overlooked but is a real recon vector — it lets a caller subscribe to a live stream of every pod event in the namespace indefinitely.

---

## 4. Token Mount Policy — `automountServiceAccountToken: false`

Set at the ServiceAccount level:

```yaml
automountServiceAccountToken: false
```

Without this, Kubernetes automatically injects the SA token into **every pod** that references the SA at:

```
/var/run/secrets/kubernetes.io/serviceaccount/token
```

This happens even for pods that never make a single API call. Disabling at the SA level and opting in per-Pod (setting `automountServiceAccountToken: true` on the Pod spec) means:

- The token is only present where explicitly required.
- A compromised container that doesn't need API access carries no usable token.
- The blast radius of a container breakout is significantly reduced.

---

## 5. RoleBinding vs ClusterRoleBinding

A **`RoleBinding`** (not `ClusterRoleBinding`) is used to bind the Role to the SA.

```yaml
kind: RoleBinding   # ✅ namespace-scoped
# vs
kind: ClusterRoleBinding  # ❌ would be cluster-wide if pointing to a ClusterRole
```

This makes the namespace boundary explicit at two levels — both the Role definition and the binding itself. It also makes audits easier: anyone reading the manifest can immediately see the scope without needing to cross-reference other objects.

---

## 6. Optional Hardening — `resourceNames`

If the application only ever inspects specific, known pods (e.g., a fixed sidecar or a named service), the rule can be further tightened with `resourceNames`:

```yaml
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
    resourceNames: ["my-app-pod", "my-app-sidecar"]  # exact pod names only
```

This prevents enumeration of all pods in the namespace — the SA can only inspect the explicitly named pods. Useful in production; omitted here to keep the dev setup functional for general pod inspection.

---

## 7. Verification

### Dry-run from your local machine

```bash
# Should return: yes
kubectl auth can-i get pods  --as=system:serviceaccount:dev:readonly-app-sa -n dev
kubectl auth can-i list pods --as=system:serviceaccount:dev:readonly-app-sa -n dev

# Should return: no
kubectl auth can-i delete pods  --as=system:serviceaccount:dev:readonly-app-sa -n dev
kubectl auth can-i get secrets  --as=system:serviceaccount:dev:readonly-app-sa -n dev
kubectl auth can-i get pods     --as=system:serviceaccount:dev:readonly-app-sa -n default
```

### From inside the test pod

```bash
kubectl exec -it rbac-test-pod -n dev -- bash

# ✅ Allowed
kubectl get pods -n dev
kubectl get pod <pod-name> -n dev

# ❌ Forbidden
kubectl delete pod <pod-name> -n dev
kubectl get secrets -n dev
kubectl get pods -n default
```

---

## 8. Summary

| Control | Mechanism | What it prevents |
|---|---|---|
| Namespace boundary | `Role` (not `ClusterRole`) | Access to any other namespace |
| Resource boundary | `resources: ["pods"]` | Access to secrets, deployments, SA tokens, etc. |
| Verb boundary | `verbs: ["get", "list"]` | Mutation, deletion, exec, watch/recon |
| Token injection | `automountServiceAccountToken: false` | Token exposure in non-API pods |
| Binding scope | `RoleBinding` (not `ClusterRoleBinding`) | Accidental cluster-wide grant |
