Lab 04 - Observability and Incident Simulation

What we did and why

This lab was about monitoring and incident response. All the security controls from Labs 1-3 are great, but if something goes wrong in production, you need to be able to see it happening, figure out what's going on, and fix it. That's what observability gives you.

We installed Prometheus and Grafana using a Helm chart (kube-prometheus-stack). Prometheus is the tool that collects metrics from the cluster. It scrapes data from nodes, Pods, and the Kubernetes API at regular intervals. Grafana is the visualization layer that turns those metrics into dashboards and graphs.

Setting things up

We installed the whole monitoring stack with one Helm command. It created a bunch of Pods in the monitoring namespace: Prometheus itself, Grafana, Alertmanager, a node exporter (collects hardware metrics), kube-state-metrics (collects Kubernetes object info), and the Prometheus operator (manages the configuration).

We accessed Grafana by port-forwarding to localhost:3000 and logged in. It came with a bunch of pre-built dashboards, including "Kubernetes / Compute Resources / Pod" which shows CPU usage, CPU throttling, memory usage, and resource quotas per Pod.

Deploying the test app

We deployed a stress-test Deployment with resource requests (100m CPU, 64Mi memory) and limits (200m CPU, 128Mi memory). In Grafana we could see the CPU usage, throttling percentage, and resource quotas for this Pod in real time.

Simulating the incident

We created a memory-bomb Pod that tried to allocate 256Mi of memory but only had a 128Mi limit. Within seconds, Kubernetes killed it with OOMKilled (Out Of Memory Killed). The Pod went into CrashLoopBackOff because every restart tried the same allocation and got killed again.

In Grafana, we could see the memory usage (WSS) graph for the memory-bomb Pod spiking up to the 128 MiB limit. The requests line sat at 64 MiB and the limits line at 128 MiB, and the actual usage was hitting that limit before getting killed.

Incident timeline

1. memory-bomb Pod deployed requesting 64Mi with a 128Mi limit
2. The stress command inside the Pod tried to allocate 256Mi
3. Memory usage hit the 128Mi limit within seconds
4. Kubernetes OOMKilled the container (terminated it for exceeding the limit)
5. Kubernetes restarted the container (restart policy: Always)
6. Same thing happened again, leading to CrashLoopBackOff after 5 restarts
7. Detected via kubectl get pods (CrashLoopBackOff status) and Grafana (memory spike to limit)
8. Root cause identified via kubectl describe pod (Reason: OOMKilled)
9. Resolution: delete the Pod, fix the application to use less memory or increase the limit

How we detected it

Two methods worked together. kubectl showed the Pod status as CrashLoopBackOff with 5 restarts, and kubectl describe showed the OOMKilled reason. Grafana showed the memory usage graph spiking to the limit line, making it visually obvious what happened.

In a real production environment, you'd also have Alertmanager configured to send Slack or PagerDuty alerts when a Pod gets OOMKilled or enters CrashLoopBackOff. You wouldn't need to be watching the dashboard, the system would notify you.

Why this matters

Without monitoring, this Pod would just keep crashing and nobody would know why. The application would be down and the team would be guessing. With Prometheus and Grafana, you can see exactly what happened, when it happened, and correlate it with resource limits. The fix becomes obvious instead of being a mystery.

Tools used

Prometheus: collects and stores metrics from the cluster
Grafana: visualizes metrics as dashboards and graphs
Alertmanager: sends notifications when things go wrong (part of the stack, not configured in this lab)
kubectl describe: shows Pod events including OOMKilled reason
kubectl get pods: shows current status and restart count

Deliverables

stress-app.yaml, memory-bomb.yaml, lab04.txt, lab04.sh, lab04_notes.md, plus screenshots of Grafana dashboards
