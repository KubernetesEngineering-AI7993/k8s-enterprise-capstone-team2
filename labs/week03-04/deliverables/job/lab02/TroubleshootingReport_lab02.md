Troubleshooting Report  
Issue Summary  
The pod toleration-demo would not schedule

Symptoms  
sudo kubectl get pods returned PENDING status instead of RUNNING.

Investigation  
sudo kubectl describe pods toleration-demo gave the following information:  
Warning  FailedScheduling  2m30s  default-scheduler  0/1 nodes are available: 1 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

Root Cause  
Incorrect definition. File taints-no-tolerance.yaml lacked a spec:tolerations structure with effect: "NoSchedule"  
As a result the created pod was created on a node that would only schedule pods tainted with dedicated=ops:NoSchedule as given by:  
(main\_env) jeking@jeking-vm:\~/ai7993/local/week3and4/week03lab02$ sudo kubectl describe node jeking-vm | grep \-i taint  
Taints:             dedicated=ops:NoSchedule  
The pod was deployed without toleration so it was not going to be scheduled by the Kubernetes node.

Resolution  
taints-tolerance.yaml containing the following was created and run. This created tolerance-demo with toleration. As a result the node scheduled the toleration-demo pod.  
spec:  
  tolerations:  
  \- key: "dedicated"  
    operator: "Equal"  
    value: "ops"  
    effect: "NoSchedule"  
  containers:  
  \- name: app  
    image: nginx

