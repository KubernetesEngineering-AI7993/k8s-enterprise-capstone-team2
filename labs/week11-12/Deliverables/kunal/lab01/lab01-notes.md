# Lab 01 - RBAC and ServiceAccounts Notes

## Least-Privilege Design

The `readonly-app-sa` ServiceAccount is scoped to namespace `dev` and only bound to a namespaced Role.

`readonly-role.yaml` grants only:
- `get` on Pods
- `list` on Pods

It does **not** grant:
- write verbs (`create`, `update`, `patch`, `delete`)
- access to other resources (Deployments, Secrets, ConfigMaps, etc.)
- access outside `dev` namespace

This is least privilege because the identity gets only the minimum Pod-read permissions required for observation.

## Frigate + SQLite + Ingress

The app stack is defined in `frigate-stack.yaml`:
- `Namespace dev`
- `PersistentVolumeClaim frigate-config-pvc` for Frigate config storage
- `Deployment frigate` using image `ghcr.io/blakeblackshear/frigate:stable`
- `Service frigate` (ClusterIP, port 80 -> 5000)
- `Ingress frigate` with class `nginx` and host `nvr.internal`

Ingress controller Service exposure is defined in `ingress-nginx-values.yaml`:
- `controller.service.type: NodePort`
- `controller.service.nodePorts.http: 30080`
- `controller.service.nodePorts.https: 30443`

SQLite is used by Frigate via:
- env var `FRIGATE_DB_PATH=/config/frigate.db`
- mounted persistent storage at `/config`

Frigate is restricted to GPU-labeled nodes by:
- `nodeSelector: { GPU: "true" }`

## Verification

Run:

```bash
bash lab01.sh
```

RBAC checks in the script:

```bash
kubectl auth can-i list pods -n dev --as system:serviceaccount:dev:readonly-app-sa
kubectl auth can-i delete pods -n dev --as system:serviceaccount:dev:readonly-app-sa
```

Expected:
- list pods: `yes`
- delete pods: `no`

If no node has `GPU=true`, Frigate will remain Pending until a node is labeled:

```bash
kubectl label node <node-name> GPU=true
```
