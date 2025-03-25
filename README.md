# K8S Cluster Installation

##  Step 0 - Host preparation

###  Installing ansible-core on the host

```shell
sudo apt install ansible-core
sudo apt install ansible-lint


```

```shell
git clone ...

```

```shell
chmod 600 inventory/multipass-ssh-key

```

```shell
bash ./01-create-multipass-instances-2.sh

```

```shell
bash ./update-nodes-ini.sh inventory/nodes.ini
```

##  Step 3 - Taking the snapshots

```shell
bash ./snaphot.sh k8s-pre-install
```

### (Optional) Verify the snapshots

```shell
multipass list --snapshots

```

## Step 6 - The rest

```shell
bash ./run.sh ./consolidated-k8s-installer-2.yaml

```

## Step 7 - Calico is not ok

### Download the Calico manifest

```shell
curl https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml -O

```

```shell
# Optional: If you used a non-default pod CIDR, edit the manifest
# Find and replace 192.168.0.0/16 with your pod network CIDR
# nano calico.yaml
```

### Apply the manifest

```shell
kubectl apply -f calico.yaml
```

```shell
# Check for Calico pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Watch the nodes becoming ready
kubectl get nodes -w
```

kubectl get pods -n kube-system
sudo systemctl status kubelet
kubectl describe nodes control-plane-01 | grep -A10 Conditions



kubectl apply -f k8s-cluster-test.yaml
kubectl get all -n k8s-test


ubuntu@control-plane-01:~$ kubeadm token create --print-join-command
kubeadm join 10.14.96.37:6443 --token q5tban.yqa9sw6im3d2z2fg --discovery-token-ca-cert-hash sha256:d7498807d0145b5e30c427682a029d4fdd97fe304b7012837f85b1141fca5bfc