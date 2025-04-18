# Commands

```shell
vm@ST-10-01:~/010-k8s-install$ kubectl exec insecure-pod -- id
uid=0(root) gid=0(root) groups=0(root)
vm@ST-10-01:~/010-k8s-install$ kubectl exec secure-pod -- id
uid=1000 gid=3000 groups=3000
```


```shell
vm@ST-10-01:~/010-k8s-install$ kubectl exec -it pod-level-security-context -- id
uid=1000 gid=3000 groups=2000,3000
vm@ST-10-01:~/010-k8s-install$ kubectl exec -it container-level-security-context -- id
uid=2000 gid=3000 groups=2000,3000
```


```shell
bash decode-capabilities unprivileged-pod
bash decode-capabilities privileged-pod

```



```shell
kubectl exec unprivileged-pod -- date -s "12:00:00"
kubectl exec privileged-pod -- date -s "12:00:00"
```




```shell
vm@ST-10-01:~/010-k8s-install/pod-security$ kubectl exec default-capabilities-pod -- ping -c 1 8.8.8.8
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: seq=0 ttl=112 time=18.793 ms

--- 8.8.8.8 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 18.793/18.793/18.793 ms
vm@ST-10-01:~/010-k8s-install/pod-security$ kubectl exec dropped-capabilities-pod -- ping -c 1 8.8.8.8
ping: permission denied (are you root?)
PING 8.8.8.8 (8.8.8.8): 56 data bytes
command terminated with exit code 1
```