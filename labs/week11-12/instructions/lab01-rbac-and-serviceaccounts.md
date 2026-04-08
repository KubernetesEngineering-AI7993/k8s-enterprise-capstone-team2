# Lab 01 – RBAC & ServiceAccounts

Focus

Least-privilege access

ServiceAccount-scoped permissions

Tasks

Create a ServiceAccount for a read-only app in dev namespace.

Create an Role that allows only:

get, list on Pods in dev

Create a RoleBinding binding the Role → ServiceAccount.

Use a Pod with that ServiceAccount and verify:

It can list Pods in dev

It cannot modify or delete resources

Deliverables

readonly-role.yaml

readonly-rolebinding.yaml

serviceaccount.yaml

Notes on why this is least privilege
