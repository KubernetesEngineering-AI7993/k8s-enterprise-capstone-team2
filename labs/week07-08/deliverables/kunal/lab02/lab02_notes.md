# Lab 02 – Multi-Container Pods

## Objective
Create a Pod with a main application container and a sidecar container, share data via an emptyDir volume, and observe how containers start, restart, and terminate together.

## What We Did

### Multi-container Pod (multi-container.yaml)
- **app**: nginx serving on port 80; serves content from `/usr/share/nginx/html`.
- **sidecar**: busybox container that appends `date` to `/data/index.html` every 5 seconds.
- **shared-data**: emptyDir volume; app mounts it at `/usr/share/nginx/html`, sidecar at `/data`. The same file (`index.html`) is written by the sidecar and served by nginx.

### Observations
- Both containers become Ready together (2/2); the Pod is scheduled as one unit on one node.
- Containers share the same network namespace (localhost) and the same volume; no Service is needed for main-app ↔ sidecar communication on the same host.
- If the Pod is deleted, both containers terminate together; emptyDir is removed with the Pod.
- Restart of one container (e.g. sidecar) does not remove the other; the Pod stays and only that container is restarted.

## Sidecar use cases

| Use case | Description |
|----------|-------------|
| **Log shipping** | Sidecar tails app logs and ships to a central system (e.g. Fluent Bit, Filebeat). |
| **Proxy / mesh** | Sidecar handles TLS or service-mesh traffic (e.g. Envoy, Istio sidecar). |
| **Config sync** | Sidecar watches ConfigMaps/secrets and writes files into a shared volume for the main app. |
| **Monitoring** | Sidecar exports metrics (e.g. Prometheus exporter) or runs health checks. |
| **Helper/init** | Sidecar prepares data in a shared volume before or while the main app runs. |

The main app stays unchanged; the sidecar extends behavior by sharing the Pod’s lifecycle, network, and volumes.

## Deliverables

- **multi-container.yaml**: Pod manifest with main container, sidecar, and emptyDir volume.
- **lab02.sh**: apply, wait, describe, curl, logs, and volume listing.
- **lab02_notes.md**: this file (sidecar use cases and behavior).
