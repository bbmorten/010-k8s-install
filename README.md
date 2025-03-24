# K8S Cluster Installation

##  Step 0 - Host preparation

###  Installing ansible-core on the host

```shell
sudo apt install ansible-core
sudo apt install ansible-lint


```


```shell
chmod 600 inventory/multipass-ssh-key

```

```shell
sh ./01-create-multipass-instances.sh
```

- Check the information on vms

```shell
bulent@BMAPMB0620 ansible-k8s-cluster-on-multipass % multipass list
Name                    State             IPv4             Image
control-plane-01        Running           192.168.64.6     Ubuntu 24.04 LTS
worker-01               Running           192.168.64.7     Ubuntu 24.04 LTS
worker-02               Running           192.168.64.8     Ubuntu 24.04 LTS
worker-03               Running           192.168.64.9     Ubuntu 24.04 LTS
```

```shell
multipass list | awk '{if (NR>1) print $1, $3}'

```

Update the nodes.ini file

##  Step 3 - Taking the snapshots

```shell
bash ./snaphot.sh k8s-pre-install
```

### (Optional) Verify the snapshots

```shell
multipass list --snapshots

```

##  Step 4 - Configure name resolution

```shell
cd /home/vm/ansible-k8s-cluster-on-multipass/playbooks/010-k8s-install
bash ./run.sh 01-name-resolution.yaml --syntax-check
bash ./run.sh 01-name-resolution.yaml --check
bash ./run.sh 01-name-resolution.yaml 

```

## Step 5 - System preparation - Update packages and disable swap

```shell
cd /home/vm/ansible-k8s-cluster-on-multipass/playbooks/010-k8s-install
bash ./run.sh 02-system-preparation.yaml --syntax-check
bash ./run.sh 02-system-preparation.yaml --check
bash ./run.sh 02-system-preparation.yaml 

```
## Step 6 - The rest

```shell
03-kubernetes_installation.yaml
04-install_crictl.yaml
05-initialize-k8s-cluster
06-join_worker_nodes.yaml
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