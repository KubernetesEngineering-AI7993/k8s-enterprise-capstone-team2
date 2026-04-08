# Lab 03 – Pod Security Standards

Focus

Preventing insecure Pod configurations.

Tasks

Apply a “restricted-like” Pod security configuration (or equivalent constraints).

Deploy a Pod that:

Runs as root

Uses privileged: true or hostPath volumes

Observe failure / rejection.

Fix the Pod spec to comply (runAsNonRoot, drop capabilities, no privileged).

Deliverables

Initial non-compliant Pod manifest (for reference)

Compliant restricted-pod.yaml

Explanation of what changed and why it’s safer
