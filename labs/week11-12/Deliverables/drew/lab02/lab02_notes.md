Lab 02 - NetworkPolicies

What we did and why

This lab was about controlling which Pods can talk to which other Pods. By default, Kubernetes has no network restrictions at all. Every Pod can reach every other Pod in the cluster. That's convenient for getting things running, but it's a security problem. If an attacker compromises one Pod, they can use it to reach everything else, your database, your secrets service, whatever.

NetworkPolicies are basically firewall rules that live inside the cluster. You define which traffic is allowed, and everything else gets blocked.

Setting up the scenario

We created three Pods in the dev namespace: a frontend, a backend, and a rogue-pod (simulating something that shouldn't have access). We also created a Service for the backend so the other Pods could reach it by name. Before applying any policies, we tested and confirmed that both the frontend AND the rogue-pod could curl the backend and get the nginx welcome page. No restrictions at all.

Step 1: Default deny

We applied a default-deny NetworkPolicy that blocks all incoming traffic to every Pod in the dev namespace. The key part is podSelector: {} which means "apply to all Pods" and policyTypes: Ingress which means "block all incoming connections."

After applying this, both the frontend and rogue-pod timed out when trying to reach the backend. Exit code 28 from curl means the connection timed out. Everything is locked down.

Step 2: Allow only frontend to backend

Then we applied a second policy that pokes a hole in the deny-all. This one says: for Pods labeled app: backend, allow incoming traffic from Pods labeled app: frontend on port 80. Everything else stays blocked.

After applying this, the frontend could reach the backend again and got the nginx welcome page. The rogue-pod still timed out. Only the specifically allowed traffic gets through.

How it works

NetworkPolicies use label selectors, the same label matching pattern we've been using since Week 5-6. The podSelector in the policy picks which Pods the rule applies to. The ingress.from.podSelector picks which Pods are allowed to send traffic. If a Pod doesn't match the allowed labels, its traffic gets dropped silently (timeout, not a rejection message).

Why this matters

This is how you prevent lateral movement. In a real cluster, if your frontend gets compromised, the attacker can only reach the backend because that's the only connection allowed. They can't reach the database directly, they can't reach the monitoring system, they can't reach other teams' services. Each connection has to be explicitly allowed.

The pattern is: start with deny-all, then add specific allow rules for the connections you actually need. This is the same approach used in traditional firewall management. Deny everything by default, whitelist what's needed.

Deliverables

apps.yaml, default-deny.yaml, allow-frontend-backend.yaml, lab02.txt, lab02.sh, lab02_notes.md
