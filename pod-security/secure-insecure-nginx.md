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