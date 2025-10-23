# Let's Install Cilium Labs with KinD for MACOS

##  Step 0: Prerequisites

- Install Docker Desktop and kind (brew install kind) on your local machine
- Create kind-config.yaml file with the following content:

```shell
cd /Users/bulent/git-repos/cilium-study/lets-install-cilium-on-kind 
```

```shell
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
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

cilium hubble enable --ui



```bash
cilium connectivity test --request-timeout 30s --connect-timeout 10s
```

```bash
kubectl get nodes
kubectl get daemonsets --all-namespaces
kubectl get deployments --all-namespaces
```
