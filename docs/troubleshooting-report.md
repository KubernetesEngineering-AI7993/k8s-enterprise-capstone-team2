# Troubleshooting Report (Warehouse CV Placeholder Platform)

## Scope

This report documents baseline troubleshooting procedures for the placeholder Kubernetes workloads before real application images are integrated.

## Known Placeholder Behavior

- Bare Ubuntu containers in Deployments and Pods have no explicit command/entrypoint override in manifests.
- Depending on runtime behavior of image defaults, containers may not remain running.
- Current probes are placeholders used only to preserve probe configuration structure for week 5-6 objectives.

## Troubleshooting Workflow

1. Confirm namespace and objects:
   - `kubectl get ns warehouse-cv`
   - `kubectl get all -n warehouse-cv`
2. Inspect scheduling placement:
   - `kubectl describe pod <pod-name> -n warehouse-cv`
   - verify node selector / toleration behavior for GPU workloads
3. Inspect resource pressure:
   - `kubectl top nodes`
   - `kubectl top pods -n warehouse-cv`
4. Verify HPA behavior:
   - `kubectl get hpa -n warehouse-cv`
5. Review events:
   - `kubectl get events -n warehouse-cv --sort-by=.metadata.creationTimestamp`
6. Validate policy impact:
   - `kubectl describe networkpolicy -n warehouse-cv`
   - `kubectl auth can-i --as=system:serviceaccount:warehouse-cv:dashboard-sa list pods -n warehouse-cv`

## Typical Failure Cases to Simulate

- Pods pending due to unavailable GPU resources.
- Pod crashes due to image startup/entrypoint behavior.
- NetworkPolicy blocking expected traffic path.
- Misconfigured secret or ConfigMap references.

## Action Plan After Real Images Arrive

- Replace placeholder probe definitions with endpoint-based probes.
- Add per-service runbooks and SLO-linked alerts.
- Expand troubleshooting matrix with service-specific failure signatures.
