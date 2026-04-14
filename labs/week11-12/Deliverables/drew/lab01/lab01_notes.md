Lab 01 - RBAC and ServiceAccounts

What we did and why

This lab was about controlling who can do what inside a Kubernetes cluster. Up until now, every command we ran had full admin access because we were using the default kubeconfig. That's fine for learning, but in a real company you wouldn't give every developer or application full control over the cluster. An intern shouldn't be able to delete production deployments. A monitoring app shouldn't be able to read secrets it doesn't need.

That's what RBAC (Role-Based Access Control) solves. You define specific permissions and only give them to the entities that actually need them. This is called least privilege.

How RBAC works

There are three pieces that work together:

A ServiceAccount is basically an identity for a Pod. Just like you have a username, a Pod gets a ServiceAccount that says "I am this entity." We created one called readonly-sa in the dev namespace.

A Role is a list of permissions. Ours says "you can get and list Pods in the dev namespace." That's it. Nothing about deleting, creating, or modifying. Just reading. We called it pod-reader.

A RoleBinding is what connects the two. It says "the readonly-sa ServiceAccount gets the pod-reader permissions." Without the binding, the Role exists but nobody has it.

What we built

We created all three resources in the dev namespace, then deployed a test Pod running with the readonly-sa ServiceAccount. We also created a dummy Pod so we'd have something to test against.

When we ran kubectl get pods from inside the test Pod, it worked. The ServiceAccount has get and list permissions, so reading Pods is allowed.

When we tried kubectl delete pod dummy-pod, it failed with a Forbidden error. The error message was actually really helpful because it spelled out exactly what went wrong: "system:serviceaccount:dev:readonly-sa cannot delete resource pods in API group in namespace dev." The Role only allows get and list, not delete.

That's least privilege in action. The Pod can see what's running but can't touch anything.

Why this matters

If an application gets compromised and it only has read-only access, the attacker can see what's running but can't delete deployments, modify secrets, or escalate their access. The damage is contained. Compare that to an app with full admin access where a single breach means the attacker owns the entire cluster.

In production you'd have different Roles for different teams. Developers might get read access to their own namespace. CI/CD pipelines might get create and update access for deployments. Only a few platform engineers would have full admin. Everyone gets exactly what they need and nothing more.

Role vs ClusterRole

We used a Role which is scoped to a single namespace (dev). There's also a ClusterRole which applies across all namespaces or to cluster-wide resources like nodes. The rule of thumb is to always start with a Role. Only use ClusterRole when you genuinely need cross-namespace access, like a monitoring tool that reads Pods everywhere.

Deliverables

serviceaccount.yaml, readonly-role.yaml, readonly-rolebinding.yaml, test-pod.yaml, lab01.txt, lab01.sh, lab01_notes.md
