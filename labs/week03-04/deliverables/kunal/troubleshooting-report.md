# Troubleshooting Report

---

## 1. CrashLoopBackOff

### Issue Summary
Pod enters CrashLoopBackOff; container starts then exits with non-zero code.

### Symptoms
- Pod status: `CrashLoopBackOff` / `Error`, Exit Code 1.
- Events show: `Back-off restarting failed container app`.
- See **lab4.txt** (Scenario 1: CrashLoopBackOff), `kubectl describe pod` output for `crashloop-demo-*`.

### Investigation
- `kubectl get pods` → pod in CrashLoopBackOff.
- `kubectl describe pod` → container **Command**: `/bin/false` (exits immediately).
- **lab4.txt** contains full describe output showing `Last State: Terminated`, `Reason: Error`, `Exit Code: 1`.

### Root Cause
Container was started with `command: ["/bin/false"]`, which exits with code 1. The controller keeps restarting the container, leading to CrashLoopBackOff.

### Resolution
Removed or commented out the failing command so the image’s default entrypoint runs. Fixed manifest: **fixed-crashloop.yaml** (no `command`). Re-apply and verify with `kubectl get pods`; see **lab4.txt** for fixed deployment output.

---

## 2. ImagePullBackOff

### Issue Summary
Pod cannot start because the container image cannot be pulled.

### Symptoms
- Pod status: `ErrImagePull` / `ImagePullBackOff`.
- No container start; image pull fails.
- See **lab4.txt** (Scenario 2: ImagePullBackOff), `kubectl describe pod` for `imagepullback-demo-*`.

### Investigation
- `kubectl get pods` → `ErrImagePull` or `ImagePullBackOff`.
- `kubectl describe pod` → **Image**: `nginx:faketag`; Events: `Failed to pull image "nginx:faketag": not found`.
- **lab4.txt** includes the full describe output and event messages.

### Root Cause
Manifest specified a non-existent image tag: `nginx:faketag`. The registry returns "not found", so the kubelet cannot pull the image.

### Resolution
Use a valid image tag. Fixed manifest: **fixed-imagepullback.yaml** (image set to `nginx`). After applying, pod reaches Running; see **lab4.txt** for fixed deployment output.

---

## 3. Pending Pods

### Issue Summary
Pod remains Pending and is never scheduled to a node.

### Symptoms
- Pod status: `Pending`, `Node: <none>`.
- Events: `FailedScheduling` — e.g. "Insufficient cpu", "Insufficient memory", or "had untolerated taint(s)".
- See **lab4.txt** (Scenario 3: Pending Pods), `kubectl describe pod` for `pendingpod-demo-*`.

### Investigation
- `kubectl get pods` → pod Pending.
- `kubectl describe pod` → **Requests**: `cpu: 100` (100 cores), `memory: 256Gi`; Conditions: `PodScheduled: False`.
- Events: `0/3 nodes are available: 1 Insufficient cpu, 1 Insufficient memory, 2 node(s) had untolerated taint(s)`.
- **lab4.txt** contains the full describe and events.

### Root Cause
Resource requests were impossible to satisfy: `cpu: "100"` (100 cores) and `memory: "256Gi"` exceed typical node capacity, so no node can schedule the pod.

### Resolution
Use feasible resource requests or omit them for a best-effort pod. Fixed manifest: **fixed-pendingpod.yaml** (no resource requests). After applying, pod schedules and runs; see **lab4.txt** for fixed deployment output.

---

## 4. Service selector mismatch

### Issue Summary
Service has no Endpoints; traffic to the Service does not reach any pod.

### Symptoms
- `kubectl get endpoints` or `kubectl describe service` shows **Endpoints**: empty (or `<none>`).
- Pods for the app are Running, but the Service selector does not match their labels.
- See **lab4.txt** (Scenario 4: Service selector mismatch), `kubectl describe service selector-demo` and `kubectl get endpointslice` output.

### Investigation
- `kubectl describe service selector-demo` → **Selector**: `app=selector-demo-wrong`.
- Deployment pods have label `app=selector-demo` (see **service-selector-mismatch.yaml**).
- `kubectl get endpointslice -l kubernetes.io/service-name=selector-demo-svc` → **ENDPOINTS**: `<unset>` for broken case.
- **lab4.txt** shows both broken (empty Endpoints) and fixed (Endpoints populated) output.

### Root Cause
Service selector (`app=selector-demo-wrong`) did not match the Deployment’s pod labels (`app=selector-demo`), so no Endpoints were created and the Service had no backends.

### Resolution
Align Service selector with pod labels. Fixed manifest: **fixed-service-selector-mismatch.yaml** (selector `app=selector-demo`). After applying, Endpoints show pod IPs; see **lab4.txt** for `Endpoints: 10.244.x.x:80,10.244.x.x:80`.
