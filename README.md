# K8S Cluster Installation

##  Step 0 - Host preparation

###  Installing ansible-core on the host

```shell title='HOST'
sudo apt install ansible-core
sudo apt install ansible-lint


```

##  Step 1 - Clone the repository for supplementals

```shell title='HOST'
git clone https://github.com/bbmorten/010-k8s-install.git
```

- Correct the permissions for the private-key

```shell title='HOST'
cd 010-k8s-install/
chmod 600 inventory/multipass-ssh-key

```

- Create the virtual machines control-plane-01, worker-01, worker-02, worker-03
  
```shell title='HOST'
bash ./01-create-multipass-instances.sh
```

- Check the status of the virtual machines. If it is ok continue with updating the inventory for the ansible script

```shell title='HOST'
bash ./update-nodes-ini.sh inventory/nodes.ini
```

- Do àpt update && apt upgrade -y on all virtual machines

```shell title='HOST'
bash ./run.sh apt-update-upgrade.yaml

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

##  Tests

```shell
kubectl apply -f k8s-cluster-test.yaml
kubectl get all -n k8s-test

kubectl get pods -n k8s-test -o wide
kubectl logs -n k8s-test job/cluster-test-job
kubectl logs -n k8s-test pod/node-viewer

# Get the NodePort assigned to the service
NODE_PORT=$(kubectl get svc -n k8s-test nginx-test -o jsonpath='{.spec.ports[0].nodePort}')

# Access from any node
curl http://<any-node-ip>:$NODE_PORT
```

## Join the cluster

```shell
ubuntu@control-plane-01:~$ kubeadm token create --print-join-command
kubeadm join 10.14.96.37:6443 --token q5tban.yqa9sw6im3d2z2fg --discovery-token-ca-cert-hash sha256:d7498807d0145b5e30c427682a029d4fdd97fe304b7012837f85b1141fca5bfc
```

##  Delete the cluster

```shell
multipass delete control-plane-01 worker-01 worker-02 worker-03 --purge

```
