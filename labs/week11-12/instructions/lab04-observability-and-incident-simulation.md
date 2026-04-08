# Lab 04 – Observability & Incident Simulation

Focus

Monitoring + incident response

Tasks

Ensure Prometheus is scraping:

Application HTTP metrics

Basic resource metrics (CPU, memory)

Build at least one Grafana dashboard showing:

Request rate / error rate (or equivalent)

Pod CPU/memory

Simulate an incident:

Option A: Introduce high error rate

Option B: Resource saturation (CPU or memory)

Use Prometheus + Grafana and kubectl to:

Detect the issue

Identify the root cause

Document the timeline

Deliverables

prometheus-scrape-config.yaml (or values snippet)

grafana-dashboard.json

incident-report.md documenting:

Symptom

Metrics observed

Root cause
Resolution
