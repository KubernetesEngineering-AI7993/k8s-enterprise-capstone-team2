# Lab 01 – Helm Charts

## Objective
Create a Helm chart for an existing application, parameterize image tag, replica count, and service type; install, upgrade, and roll back the release.

## What We Did

### Created a Helm chart (sample-app)
- Aligned with **solutions/helm/sample-app**.
- **Chart.yaml**: chart metadata (name, version, appVersion).
- **values.yaml**: default values for replicaCount, image.repository/tag, service.type and service.port.
- **templates/deployment.yaml**, **templates/service.yaml**: Kubernetes manifests using `{{ .Release.Name }}` and `{{ .Values.* }}` (no _helpers.tpl).

### Parameterized values
- **Image tag**: `image.tag` in values.yaml (default `"1.27"`); overridable with `--set image.tag=1.26`.
- **Replica count**: `replicaCount` (default `1`); overridable with `--set replicaCount=2`.
- **Service type**: `service.type` (default `ClusterIP`); overridable with `--set service.type=NodePort`.

### Install
- `helm install sample-app ./sample-app` deploys the chart as revision 1.
- Helm renders the templates with default values and applies the resulting Deployment and Service.

### Upgrade
- `helm upgrade sample-app ./sample-app --set replicaCount=2 --set service.type=NodePort --set image.tag=1.26` creates revision 2 with the new values.
- Kubernetes performs a rolling update of the Deployment and updates the Service type.

### Rollback
- `helm rollback sample-app 1` reverts to revision 1 (creates a new revision 3 with revision 1’s state).
- Rollback is immediate from Helm’s perspective; Kubernetes then rolls the workload back to the previous spec.

## values.yaml

`values.yaml` is the chart’s default configuration. Every template value should have a default here. Key entries:

- **replicaCount**: number of Pod replicas in the Deployment.
- **image.repository**, **image.tag**, **image.pullPolicy**: container image and pull behavior.
- **service.type**: ClusterIP, NodePort, or LoadBalancer.
- **service.port**: port the Service exposes and the container listens on.

Overrides can be done via `--set`, `-f custom-values.yaml`, or `--set-file` without editing the chart.

## Templates vs raw YAML

| Raw YAML | Helm templates |
|----------|----------------|
| Fixed values (e.g. `replicas: 2`, `image: nginx:1.27`). | Placeholders like `{{ .Values.replicaCount }}`, `{{ .Values.image.tag }}`. |
| One file per environment or manual edits. | One chart; different environments use different value files or `--set`. |
| No built-in release history. | Revisions tracked by Helm; rollback by revision number. |

Templates can use conditionals (`if`/`else`), loops (`range`), and helpers (`define`/`include`) for more complex charts.

## Rollback behavior

- Helm stores each install/upgrade as a **revision** (1, 2, 3, …).
- `helm rollback RELEASE REVISION` applies the **state of that revision** again and creates a **new** revision (it does not “undo” the last one).
- Example: rev 1 = install, rev 2 = upgrade, `helm rollback sample-app 1` → rev 3 has the same config as rev 1.
- `helm history RELEASE` shows all revisions; you can roll back to any of them.
- The actual Pod/Deployment changes are done by Kubernetes (e.g. rolling update); Helm only reapplies the manifest from the chosen revision.

## Deliverables

- **sample-app/**: Helm chart under `lab01/sample-app/` (aligns with “solutions/helm” style; chart is self-contained in the lab).
- **lab01.sh**: install, upgrade, rollback and listing commands.
- **lab01_notes.md**: this file (values.yaml, templates vs raw YAML, rollback behavior).
