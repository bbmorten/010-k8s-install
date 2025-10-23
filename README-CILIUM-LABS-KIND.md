# Let's Install Cilium Labs with KinD for MACOS

##  Step 0: Prerequisites

- Install Docker Desktop and kind (brew install kind) on your local machine
- Create kind-config.yaml file with the following content:

```shell
cd /Users/bulent/git-repos/cilium-study/lets-install-cilium-on-kind 
```

To delete the cluster when you are done, run: (Optional)

```shell
kind delete cluster -n cilium-labs
```

```shell
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: /Users/bulent/data/kind-storage         
        containerPath: /var/local-path-provisioner
  - role: worker
    extraMounts:
      - hostPath: /Users/bulent/data/kind-storage         
        containerPath: /var/local-path-provisioner
  - role: worker
    extraMounts:
      - hostPath: /Users/bulent/data/kind-storage        
        containerPath: /var/local-path-provisioner
networking:
  disableDefaultCNI: true
EOF
```

## Step 1: Create a KinD Cluster

```bash
kind create cluster --name cilium-labs --config kind-config.yaml
```

```bash
kubectl cluster-info --context kind-cilium-labs
kubectl cluster-info dump

```

```bash
kubectl get nodes
```

```bash
cilium version
```

```bash
cilium connectivity test --request-timeout 30s --connect-timeout 10s
```
  
```bash
cilium install
```

```bash
cilium status --wait
```

```shell
cilium hubble enable --ui
```

```bash
cilium connectivity test --request-timeout 30s --connect-timeout 10s
```

```bash
kubectl get nodes
kubectl get daemonsets --all-namespaces
kubectl get deployments --all-namespaces
```

## Step 2: Verify Local Storage Provisioner

- KinD clusters come with Rancher's local-path-provisioner pre-installed. First, let's verify the existing setup:

```bash
kubectl get storageclass
kubectl get pods -n local-path-storage
```

- If the local-path StorageClass is not present or not set as default, install/configure it:

```bash
# Only run if local-path StorageClass doesn't exist
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/main/deploy/local-path-storage.yaml

# Set as default StorageClass if not already set
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify the setup
kubectl get storageclass
```

- Test local storage with a sample PVC and Pod:

```bash
cat > demo-pvc-pod.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata: 
  name: demo-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  resources: 
    requests: 
      storage: 2Gi
  storageClassName: local-path
---
apiVersion: v1
kind: Pod
metadata: 
  name: demo-pod
spec:
  containers:
    - name: app
      image: busybox:1.35
      command: ["sh", "-c", "echo 'Testing storage...' > /data/test.txt && sleep 3600"]
      volumeMounts: 
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: demo-pvc
EOF
```

```bash
kubectl apply -f demo-pvc-pod.yaml

# Wait for resources to be ready
kubectl wait --for=condition=Bound pvc/demo-pvc --timeout=60s
kubectl wait --for=condition=Ready pod/demo-pod --timeout=120s

# Verify the setup
kubectl get pvc demo-pvc
kubectl get pod demo-pod
kubectl describe pvc demo-pvc

# Test file creation
kubectl exec demo-pod -- ls -la /data/
kubectl exec demo-pod -- cat /data/test.txt

# Create a second pod that accesses the same PVC
cat > demo-pod-2.yaml << EOF
apiVersion: v1
kind: Pod
metadata: 
  name: demo-pod-2
spec:
  containers:
    - name: app
      image: busybox:1.35
      command: ["sh", "-c", "echo 'Hello from pod 2!' >> /data/pod2.txt && cat /data/test.txt && sleep 3600"]
      volumeMounts: 
        - name: shared-data
          mountPath: /data
  volumes:
    - name: shared-data
      persistentVolumeClaim:
        claimName: demo-pvc
EOF

kubectl apply -f demo-pod-2.yaml

# Wait for the second pod to be ready
kubectl wait --for=condition=Ready pod/demo-pod-2 --timeout=120s

# Verify both pods can access the same data
echo "=== Files from demo-pod ==="
kubectl exec demo-pod -- ls -la /data/
echo "=== Files from demo-pod-2 ==="
kubectl exec demo-pod-2 -- ls -la /data/
echo "=== Reading original file from pod-2 ==="
kubectl exec demo-pod-2 -- cat /data/test.txt
echo "=== Reading new file from pod-1 ==="
kubectl exec demo-pod -- cat /data/pod2.txt

# Create a file from pod-1 and read it from pod-2
kubectl exec demo-pod -- sh -c "echo 'Created by pod-1 after pod-2 started' > /data/shared.txt"
kubectl exec demo-pod-2 -- cat /data/shared.txt

# Cleanup when done
kubectl delete -f demo-pvc-pod.yaml
kubectl delete -f demo-pod-2.yaml
```
