# K8S Cluster Installation

##  Step 0 - Host preparation

###  Installing ansible-core on the host

```shell title='HOST'
sudo apt update && apt upgrade -y
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

##  Step 2 - Taking the snapshots before cluster installation

```shell
bash ./snapshot.sh k8s-pre-install
```

### (Optional) Verify the snapshots

```shell
multipass list --snapshots

```

## Step 3 - Start cluster installation

```shell title='HOST'
bash ./run.sh ./consolidated-k8s-installer-3.yaml

```

##  Step 4 - Testing the cluster

```shell title='HOST'
multipass shell control-plane-01
```

```shell title='control-plane-01'
# Watch the nodes becoming ready
kubectl get nodes -w
```

```shell title='control-plane-01'
kubectl get pods -n kube-system

sudo systemctl status kubelet

kubectl describe nodes control-plane-01 | grep -A10 Conditions
```

###  Step 5 - Take another snapshot after successfull cluster installation

```shell
bash ./snapshot.sh k8s-install-completed
```

###  Step 6 - Kubernetes cluster Test Deployment

I've created a comprehensive test deployment to verify your Kubernetes cluster is working properly. This YAML file contains multiple resources that will help you confirm all components are functioning correctly across your control plane and worker nodes.

## How to use it

1. the YAML file as `k8s-cluster-test.yaml`

2. Apply it to your cluster from the control plane node:

   ```bash
   kubectl apply -f k8s-cluster-test.yaml
   ```

3. Check that all resources are created properly:

   ```bash
   kubectl get all -n k8s-test
   ```

## What this test deployment includes

1. **Namespace**: Creates a dedicated `k8s-test` namespace to isolate test resources

2. **NGINX Deployment**:
   - Creates 4 replica pods (one for each node in your cluster)
   - Uses pod anti-affinity to spread pods across different nodes
   - Includes health checks and resource limits

3. **Service**: Exposes the NGINX deployment as a NodePort service

4. **ConfigMap**: Creates a custom HTML page showing pod details

5. **Test Job**: Runs a series of tests to check:
   - DNS resolution
   - API server connectivity
   - Network connectivity between pods

6. **Monitoring Pod**: Provides real-time information about:
   - Node status
   - Pod distribution across nodes
   - Control plane component status

## How to verify the results

1. Check that pods are distributed across all nodes:

   ```bash
   kubectl get pods -n k8s-test -o wide
   ```

2. View the test job results:

   ```bash
   kubectl logs -n k8s-test job/cluster-test-job
   ```

3. Check the node-viewer pod for cluster status:

   ```bash
   kubectl logs -n k8s-test pod/node-viewer
   ```

4. Access the NGINX test page from any node:

   ```bash
   # Get the NodePort assigned to the service
   NODE_PORT=$(kubectl get svc -n k8s-test nginx-test -o jsonpath='{.spec.ports[0].nodePort}')
   
   # Access from any node
   curl http://<any-node-ip>:$NODE_PORT
   ```

If all components show as running and the tests pass, your Kubernetes cluster is properly configured and operational across all nodes!

## Appendix

### Delete the cluster

```shell
multipass delete control-plane-01 worker-01 worker-02 worker-03 --purge

```

### If Calico is not ok (optional/obsolote)

To remove and reapply Calico on your Kubernetes cluster, follow these steps:

### Step 1: Delete the existing Calico installation

```bash
# First, remove all Calico resources
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

This command will delete all Calico components including the DaemonSets, Deployments, ConfigMaps, and CRDs. Wait until all Calico resources are removed before proceeding.

### Step 2: Make sure all related pods are terminated

```bash
# Check if all calico pods are terminated
kubectl get pods -n kube-system | grep calico
```

If any pods remain in "Terminating" state for a long time, you may need to force delete them:

```bash
kubectl delete pod -n kube-system <pod-name> --grace-period=0 --force
```

### Step 3: Clean up CNI configuration on all nodes

SSH into each node (control plane and workers) and run:

```bash
# Remove CNI configuration files
sudo rm -rf /etc/cni/net.d/*

# Restart kubelet
sudo systemctl restart kubelet
```

### Step 4: Reinstall Calico

Download and customize the Calico manifest if needed:

```bash
# Download the manifest
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O

# Edit the manifest if you need to change settings
# For example, if you need to modify the Pod CIDR
# Modify the CALICO_IPV4POOL_CIDR value in the manifest
nano calico.yaml
```

Then apply the manifest:

```bash
kubectl apply -f calico.yaml
```

### Step 5: Verify the installation

```bash
# Check if Calico pods are running
kubectl get pods -n kube-system | grep calico

# Check nodes status
kubectl get nodes
```

### Step 6: Validate network connectivity

You can run a simple test deployment to verify that the pod network is functioning:

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx

# Expose it as a service
kubectl expose deployment nginx --port=80

# Create a test pod to access the service
kubectl run busybox --image=busybox:1.28 -- sleep 3600

# Test connectivity from the busybox pod
kubectl exec -it busybox -- wget -qO- nginx
```

If the reinstallation of Calico doesn't resolve your issues, you might need to look more deeply at your specific cluster configuration, such as pod CIDR ranges, node networking, or potential conflicts with your host network.

### Extend the memory of an instance if necessary

```shell
multipass stop control-plane-01
multipass set local.control-plane-01.memory=8G
multipass start control-plane-01
multipass info control-plane-01
```
