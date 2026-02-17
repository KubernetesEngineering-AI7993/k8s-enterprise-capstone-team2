Troubleshooting Report  
Issue Summary  
The crashloop-demo pod would not run the nginx container.

Symptoms  
Displaying the pod revealed its CrashLoopBackOff state and several restarts.

Investigation  
sudo kubectl get pods gave below. Contrast the healthy sample-app container with the restarting and CrashLoopBackOff crashloop-demo container:  
NAME                              READY   STATUS             RESTARTS      AGE  
crashloop-demo-6587886f59-jvdwk   0/1     CrashLoopBackOff   5 (59s ago)   3m55s  
sample-app-786968857d-w2v76       1/1     Running            0             37m

sudo kubectl get events | grep crashloop-demo-6587886f59-jvdwk showed a BackOff of the failed container:  
2m31s       Warning   BackOff                   pod/crashloop-demo-6587886f59-jvdwk    Back-off restarting failed container app in pod crashloop-demo-6587886f59-jvdwk\_default(45fb9bae-a6a0-459b-a148-07ba7b46bd59

However the container logs were blank:  
sudo kubectl logs crashloop-demo-6587886f59-jvdwk

In contrast with the healthy container:  
sudo kubectl logs sample-app-786968857d-w2v76 | head \-n 5  
10.42.0.131 \- \- \[17/Feb/2026:02:03:59 \+0000\] "GET / HTTP/1.1" 200 615 "-" "Wget" "-"  
Indicating that the container was exiting before logs were able to be written.

Root Cause  
crashloop.yaml sends the command /bin/false immediately after the container starts, causing it to exit.

Resolution  
It was fixed by creating a new crashloop-fixed.yaml file that omitted command: \["/bin/false"\] and running sudo kubectl apply \-f crashloop-fixed.yaml  
in order to create a new crashloop-demo deployment and container.   
The result was a running container:  
sudo kubectl get pods  
NAME                              READY   STATUS    RESTARTS   AGE  
crashloop-demo-8665695cb6-xxv49   1/1     Running   0          2m39s  
sample-app-786968857d-w2v76       1/1     Running   0          62m

and healthy logs:  
sudo kubectl logs crashloop-demo-8665695cb6-xxv49  
sudo kubectl logs crashloop-demo-8665695cb6-xxv49  
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration  
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/  
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh  
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf  
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf  
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh  
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh  
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh  
/docker-entrypoint.sh: Configuration complete; ready for start up  
2026/02/17 02:53:29 \[notice\] 1\#1: using the "epoll" event method  
2026/02/17 02:53:29 \[notice\] 1\#1: nginx/1.29.5  
2026/02/17 02:53:29 \[notice\] 1\#1: built by gcc 14.2.0 (Debian 14.2.0-19)  
2026/02/17 02:53:29 \[notice\] 1\#1: OS: Linux 6.8.0-94-generic  
2026/02/17 02:53:29 \[notice\] 1\#1: getrlimit(RLIMIT\_NOFILE): 1048576:1048576  
2026/02/17 02:53:29 \[notice\] 1\#1: start worker processes  
2026/02/17 02:53:29 \[notice\] 1\#1: start worker process 29  
2026/02/17 02:53:29 \[notice\] 1\#1: start worker process 30  
2026/02/17 02:53:29 \[notice\] 1\#1: start worker process 31  
2026/02/17 02:53:29 \[notice\] 1\#1: start worker process 32

The events are also as expected:  
sudo kubectl get events | grep crashloop-demo-8665695cb6-xxv49  
7m36s       Normal    Scheduled           pod/crashloop-demo-8665695cb6-xxv49    Successfully assigned default/crashloop-demo-8665695cb6-xxv49 to jeking-vm  
7m36s       Normal    Pulling             pod/crashloop-demo-8665695cb6-xxv49    Pulling image "nginx"  
7m35s       Normal    Pulled              pod/crashloop-demo-8665695cb6-xxv49    Successfully pulled image "nginx" in 825ms (825ms including waiting). Image size: 62939286 bytes.  
7m35s       Normal    Created             pod/crashloop-demo-8665695cb6-xxv49    Created container: app  
7m35s       Normal    Started             pod/crashloop-demo-8665695cb6-xxv49    Started container app  
7m36s       Normal    SuccessfulCreate    replicaset/crashloop-demo-8665695cb6   Created pod: crashloop-demo-8665695cb6-xxv49  
