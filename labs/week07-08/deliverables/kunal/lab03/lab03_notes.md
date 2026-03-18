# Lab 03 – CI Pipeline

## Objective
Create a CI pipeline (GitHub Actions) that validates YAML, mocks a container build, and performs a deploy (Helm/kubectl). Pipeline runs **only when a PR is merged** (not on push or on PR open/update).

## Pipeline (ci-pipeline.yaml)

- **Trigger**: `on: pull_request: types: [closed]` with `if: github.event.pull_request.merged == true` — runs only when a pull request is closed **and** merged (not when the PR is closed without merging).
- **Job**: `validate-and-deploy`, runs on `ubuntu-latest`.
- **Steps**:
  1. **Checkout**: `actions/checkout@v4` — clones the repo.
  2. **Validate YAML**: Finds `*.yaml`/`*.yml` under the lab deliverables, skips Helm `templates/` (raw YAML only), and runs `python3 -c "import yaml; yaml.safe_load(open(...))"` per file. Fails the job if any file is invalid.
  3. **Build container image (mock)**: Echo step; in production this would run `docker build` and push to a registry.
  4. **Set up Helm**: `azure/setup-helm@v4` so `helm` is available.
  5. **Deploy (Helm template / dry-run)**: Runs `helm template sample-app ... --namespace dev` to render manifests. In production this would be `helm upgrade --install` or `kubectl apply` with cluster credentials from secrets.

## Pipeline stages summary

| Stage    | Purpose |
|----------|--------|
| Validate | Ensure manifest and values YAML are valid before deploy. |
| Build    | Mock step; real CI would build and push the app image. |
| Deploy   | Here: render with `helm template`; real CI would apply to a cluster via Helm or kubectl. |