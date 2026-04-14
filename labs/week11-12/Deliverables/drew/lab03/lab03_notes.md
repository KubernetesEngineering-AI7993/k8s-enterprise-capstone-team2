Lab 03 - Pod Security Standards

What we did and why

This lab was about preventing containers from running with dangerous privileges. RBAC controls who can do what. NetworkPolicies control which Pods can talk to each other. Pod Security Standards control how Pods are actually allowed to run. Can a container run as root? Can it access the host filesystem? Can it run in privileged mode and basically take over the node?

By default, Kubernetes lets you do all of these things. Nothing stops you from deploying a container that runs as root with full privileged access. That's a huge security risk because a privileged container can escape its sandbox and compromise the entire node it's running on.

What we built

We created a namespace called "restricted" with Pod Security Standards enforced via labels. The labels pod-security.kubernetes.io/enforce: restricted and pod-security.kubernetes.io/warn: restricted tell Kubernetes to reject any Pod that doesn't meet the restricted security profile and also print warnings explaining why.

Breaking the rules on purpose

We created a bad Pod (bad-pod.yaml) that intentionally violated the rules. It set runAsUser: 0 (root) and privileged: true. When we tried to apply it, Kubernetes rejected it immediately with a detailed error listing six violations: running as root, privileged mode, missing capability drops, no seccomp profile, and others.

This is the key behavior. The Pod never gets created. It's not like a warning you can ignore. Kubernetes flat out refuses to schedule it. The bad configuration never reaches the cluster.

Fixing the Pod

We then created a compliant Pod (restricted-pod.yaml) that addressed every violation:
- runAsNonRoot: true (can't run as root)
- runAsUser: 1000 (runs as unprivileged user)
- allowPrivilegeEscalation: false (can't gain more privileges)
- capabilities: drop: ALL (no Linux capabilities)
- seccompProfile: type: RuntimeDefault (restricts system calls)

We also had to switch from the regular nginx image to nginxinc/nginx-unprivileged because regular nginx needs root to bind to port 80. The unprivileged version listens on port 8080 instead, so it works without root. This is a real world consideration. When you enforce non-root policies, you need images that are designed to run without root.

The three security levels

Kubernetes has three built-in security levels:
- Privileged: no restrictions at all. Anything goes. This is the default.
- Baseline: prevents the most dangerous configurations (no privileged, no hostNetwork, no hostPID).
- Restricted: the strictest level. Must run as non-root, must drop all capabilities, must set seccomp profile. This is what we used.

Why this matters

If an attacker gets code execution inside a container that runs as root with privileged access, they can escape the container and own the node. From the node, they can access every other Pod on that node, read secrets from the kubelet, and potentially compromise the entire cluster.

Running as non-root with dropped capabilities means even if an attacker gets into the container, they're stuck as an unprivileged user with no special access. The damage is contained.

Deliverables

restricted-namespace.yaml, bad-pod.yaml, restricted-pod.yaml, lab03.txt, lab03.sh, lab03_notes.md
