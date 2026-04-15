# Lab 03 - Pod Security Standards Notes

## Restricted Enforcement

Namespace `pss-lab` is labeled with:
- `pod-security.kubernetes.io/enforce=restricted`
- `pod-security.kubernetes.io/enforce-version=latest`

This causes Kubernetes admission to reject Pods that violate restricted controls.

## Non-compliant Pod (Expected Rejection)

`non-compliant-pod.yaml` is intentionally unsafe:
- `runAsUser: 0` (root)
- `privileged: true`
- `hostPath` mount of `/`
- `hostPID: true`

These settings expand host attack surface and break namespace isolation, so they are rejected under restricted policy.

## Compliant Pod (Accepted)

`restricted-pod.yaml` is adjusted to be safer:
- container image runs unprivileged (`nginxinc/nginx-unprivileged`)
- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- all Linux capabilities dropped
- default seccomp profile enabled (`RuntimeDefault`)
- no privileged mode and no hostPath

## Verification

Run:

```bash
bash lab03.sh
```

Expected:
- apply of `non-compliant-pod.yaml` fails admission
- `restricted-pod` starts and becomes Ready
