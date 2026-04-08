# Lab 02 – NetworkPolicies

Focus

Traffic isolation between namespaces and apps.

Tasks

Create a default-deny NetworkPolicy in dev namespace.

Allow traffic only:

From frontend Pods to backend Pods on port (e.g. 8080)

Verify:

Frontend → backend works

Other Pods / namespaces cannot reach backend

Deliverables

default-deny.yaml

allow-frontend-backend.yaml

Notes with kubectl exec curl tests showing allowed/blocked traffic
