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
