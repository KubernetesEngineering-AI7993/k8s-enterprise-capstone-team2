# Lab 02 - Multi-Container Pods

## Objective
Create a Pod with multiple containers using the sidecar pattern, share data between containers using an emptyDir volume, and observe container lifecycle behavior.

## What We Did

### Created a Multi-Container Pod (multi-container.yaml)
Created a Pod called sidecar-demo with two containers:
- main-app: nginx:1.27 serving web traffic and writing access logs to /var/log/nginx
- log-sidecar: busybox:1.36 reading those logs every 10 seconds and printing them

Both containers mount the same emptyDir volume called shared-logs at /var/log/nginx. This means nginx writes log files there, and the sidecar reads the exact same files without any network communication between them.

### Verified Shared Volume
Ran curl against the main app to generate traffic, then checked the sidecar logs. The sidecar printed the nginx access log entries proving it could read files written by the main container. Both containers showed the same files (access.log, error.log) when listing /var/log/nginx.

### Observed Container Lifecycle
Both containers show 2/2 READY in the Pod status. When one container restarts, only that container is restarted - the other keeps running. The Pod itself is not recreated. Both containers share the same lifecycle in terms of scheduling - they always run on the same node and are created/deleted together as a unit.

## Sidecar Pattern Explanation

The sidecar pattern runs a helper container alongside your main application container in the same Pod. The sidecar extends functionality without modifying the main app code.

Common sidecar use cases:
- Log shipping: sidecar reads logs and sends them to a central system (what we built)
- Proxy: sidecar handles TLS termination or service mesh communication (Istio/Envoy)
- Config sync: sidecar watches for config changes and updates files
- Monitoring: sidecar collects metrics and exports them to Prometheus
- Data sync: sidecar pulls data from an external source into a shared volume

The main app does not know or care about the sidecar. It just writes logs to a directory like it normally would. The sidecar independently reads from that directory. This separation of concerns keeps each container focused on one job.

## How Containers Share Data

emptyDir volume: a temporary directory created when the Pod starts and deleted when the Pod is removed. Both containers mount it at the same path. Any file written by one container is immediately visible to the other.

Key properties:
- Created fresh with the Pod 
- Shared between all containers in the Pod
- Deleted when the Pod is removed 
- Lives on the node's filesystem 

## Shared Network

Containers in the same Pod share localhost. The main app listens on port 80, and we tested it by running curl localhost from inside the main container. If the sidecar needed to call the main app, it would also use localhost:80. No Service needed for intra-Pod communication.

## Key Differences: Multi-Container Pod vs Separate Pods

| Aspect | Multi-Container Pod | Separate Pods |
|--------|-------------------|---------------|
| Communication | localhost | Service + DNS |
| Shared storage | emptyDir volumes | PersistentVolumeClaim |
| Lifecycle | Start/stop together | Independent |
| Scheduling | Always same node | Can be different nodes |
| Use case | Tightly coupled helpers | Independent services |

## Deliverables
- multi-container.yaml: Pod manifest with main app and sidecar container
- lab02.sh: commands used throughout the lab
- lab02.txt: output evidence (pod status, describe, sidecar logs)
- lab02_notes.md: this file
