# K8S Cluster Installation

##  Step 0 - Host preparation

###  Installing ansible-core on the host

```shell
sudo apt install ansible-core
sudo apt install ansible-lint


```

### Generate a ssh-key pair

```shell
#mkdir -p /Users/bulent/git-repos-3/ansible-k8s-cluster-on-multipass/playbooks/001-ssh-key-pair/inventory
cd /Users/bulent/git-repos-3/ansible-k8s-cluster-on-multipass/playbooks/001-ssh-key-pair/inventory
ssh-keygen -C ubuntu -f multipass-ssh-key
```

## Step 1 - Create virtual machines (1 Control Plane and 3 nodes)

### Create a cloud-init.yaml

```yaml
users:
  - default
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - |
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJilzM4pUEiaCAw3CTdc2ikEsNCkeVwLxC+GVcFvlfV ubuntu

```

### Create a bash script

```shell
#!/bin/bash

# On the HOST
# Create Multipass Instances
multipass launch --name control-plane-01 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
multipass launch --name worker-01 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml 
multipass launch --name worker-02 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
multipass launch --name worker-03 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
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

##  Step 2 - Test the reachability to the hosts

-- needs improvement

```shell
001-ping
002-uptime
005-sudo-needed
```

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