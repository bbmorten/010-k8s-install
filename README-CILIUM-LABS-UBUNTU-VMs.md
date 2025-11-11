# K8S Cluster Installation with Ansible from MAC Host Usimf

##  Step 1 - Clone the repository for supplementals

```shell title='HOST'
cd ~/git-repos/cilium-study
git clone https://github.com/bbmorten/010-k8s-install.git -b cilium-lab-installation
```

- Correct the permissions for the private-key

```shell title='HOST'
cd 010-k8s-install/
```

```shell title='HOST'
chmod 600 inventory/multipass-ssh-key

```

- Create the phyton environment for ansible

```shell title='HOST'
# Create a Python virtual environment using uv
uv venv .venv

# Activate the virtual environment
source .venv/bin/activate

# Install Ansible Core and Ansible Lint inside the virtual environment
uv pip install ansible ansible-core ansible-lint
```

- Do apt update && apt upgrade -y on all virtual machines

```shell title='HOST'
bash ./run.sh apt-update-upgrade.yaml

```

## Step 2 - Delete cluster installation (if exists)

```shell title='HOST'
bash ./run.sh ./delete-cluster-v2.yaml

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

```shell

 # Step 1: First apply just the RBAC resources
  kubectl apply -f 01-namespace-rbac.yaml
```

```shell
  # Step 2: Wait a moment for the resources to be properly created
  sleep 10
  kubectl apply -f 02-main-resources.yaml

```

```shell
  # Wait for the main resources to be created
  sleep 10
  # Step 3: Apply all
  kubectl apply -f 03-node-viewer.yaml


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

## Appendix 1

### Delete the cluster

```shell
multipass delete control-plane-01 worker-01 worker-02 worker-03 --purge

```

### If Calico is not ok (optional/obsolote)

To remove and reapply Calico on your Kubernetes cluster, follow these steps:

### Step 1: Delete the existing Calico installation

```bash
# First, remove all Calico resources
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/calico.yaml
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

##  Appendix 2

When running a Kubernetes cluster on a QEMU-based host, you need to consider factors like nested virtualization overhead, resource efficiency, and the level of isolation required. Here’s a breakdown of your options:

### Multipass Instance (Default QEMU Backend)

- **What it is:**  
  Multipass using its default QEMU backend launches full virtual machines with their own kernel.
- **Pros:**
  - Provides strong isolation since each instance is a full VM.
- **Cons:**
  - On a QEMU host, you’re likely to run into nested virtualization. This can lead to performance penalties and additional resource overhead.
  - Boot times are longer compared to container-based solutions.

### LXD Containers

- **What they are:**  
  LXD containers share the host kernel using lightweight OS-level virtualization.
- **Pros:**
  - Much lower overhead and faster startup since there’s no need to boot a full OS.
  - Ideal for development or testing clusters because they’re resource-efficient.
- **Cons:**
  - Since containers share the host kernel, isolation isn’t as complete as with full VMs. This is usually acceptable for development, but might not be ideal in some production scenarios.

### Multipass with LXC (LXD) Driver

- **What it is:**  
  Multipass can be configured (with `multipass set local.driver=lxd`) to use LXD as its backend. This gives you the convenience of Multipass’s interface while provisioning LXD containers.
- **Pros:**
  - Combines the ease-of-use of Multipass with the efficiency of LXD containers.
  - Avoids nested virtualization, making it a great fit for your QEMU environment.
- **Cons:**
  - Essentially the same as using LXD directly, so if you need full VM isolation, this isn’t the option.

### QEMU Instances Directly

- **What it is:**  
  Launching full QEMU virtual machines outside of Multipass.
- **Pros:**
  - Full isolation and customization of the VM environment.
- **Cons:**
  - If your host is already a QEMU VM, you’d be nesting VMs, which can significantly degrade performance.
  - More complex management compared to Multipass or LXD.

### Other Options

- **Kubernetes-in-Docker (kind) or Lightweight Distributions (k3s, microk8s):**
  - These tools are designed specifically for running Kubernetes clusters in development environments.
  - **Pros:**
    - They’re optimized for local testing, have minimal overhead, and are easy to set up.
  - **Cons:**
    - They may not closely mimic a production environment if that is a requirement.
- **Bare Metal or Dedicated VMs (if possible):**
  - For production-level isolation and performance, running Kubernetes on dedicated hardware or full VMs (outside of nested virtualization) is preferred. However, this might not be feasible if you’re already constrained to a QEMU-based setup.

### Which Is Better for Your QEMU Host?

Given that you’re running on a QEMU VM:

- **Avoiding Nested Virtualization:**  
  Using Multipass with its default QEMU backend or standalone QEMU instances can introduce nested virtualization overhead. This can lead to degraded performance and potential issues with resource management.
- **Efficiency and Speed:**  
  **LXD containers (or Multipass with the LXD driver)** are generally a better choice in this scenario. They are lightweight, start quickly, and avoid the complications of nested virtualization. This is especially useful for a Kubernetes cluster where you might be running several nodes that need to communicate efficiently.
- **Use Case Considerations:**
  - **Development/Testing:** LXD containers (or Multipass with the LXD driver) are ideal for quickly spinning up a multi-node Kubernetes cluster for development or testing.
  - **Production Simulation:** If you need to mimic a production environment more closely (with full VM isolation), you might lean toward full VMs. However, doing so on a QEMU host can be challenging due to the nested virtualization overhead.

### Final Recommendation

For a Kubernetes cluster running on a QEMU host where performance and ease-of-use are priorities, **using LXD containers or Multipass configured with the LXD (LXC) driver** is generally the best approach. This method minimizes overhead by avoiding nested virtualization while providing sufficient isolation and resource control for development or test clusters.

##  Cilium Installation

- Install the Cilium CLI

```shell
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

- Install Cilium

```shell
cilium install
```

- Validate Cilium Operation

```shell
cilium connectivity test --request-timeout 30s --connect-timeout 10s

```

```shell
# Multiple custom targets (Quad9 + OpenDNS)
cilium connectivity test \
  --external-target dns.google
  --external-ip 146.112.61.106

  --request-timeout 30s --connect-timeout 10s
```

- Hand-on with L4 and L7 Network Policy

```shell
kubectl create -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/http-sw-app.yaml
```

```shell
kubectl get services
kubectl get pods,CiliumEndpoints

```

```shell
kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
```

The Death Star service is up and running, time to implement network policy and limit access to it from just the pods we want.

```shell
vm@ST-10-01:~$ kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
```

```shell
vm@ST-10-01:~$ kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
```

- Empire Ingress Allow Policy

```shell
vm@ST-10-01:~$ kubectl describe pod/xwing
Name:             xwing
Namespace:        default
Priority:         0
Service Account:  default
Node:             st-10-03/192.168.48.133
Start Time:       Tue, 11 Nov 2025 12:49:03 +0000
Labels:           app.kubernetes.io/name=xwing
                  class=xwing
                  org=alliance
```

```shell
vm@ST-10-01:~$ kubectl describe pod/tiefighter
Name:             tiefighter
Namespace:        default
Priority:         0
Service Account:  default
Node:             st-10-04/192.168.48.134
Start Time:       Tue, 11 Nov 2025 12:49:03 +0000
Labels:           app.kubernetes.io/name=tiefighter
                  class=tiefighter
                  org=empire
```

```yaml title='Allow Empire In'
mkdir yamls
cd yamls
cat > allow-empire-in-namespace.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-empire-in-namespace
spec:
  podSelector:
    matchLabels:
      org: empire
      class: deathstar
  ingress:
    - from:
        - podSelector:
            matchLabels:
              org: empire
      ports:
        - port: 80
          protocol: TCP
EOF
```

```shell
kubectl apply -f allow-empire-in-namespace.yaml

```

```shell
vm@ST-10-01:~/yamls$ kubectl apply -f allow-empire-in-namespace.yaml
networkpolicy.networking.k8s.io/allow-empire-in-namespace created

vm@ST-10-01:~/yamls$ kubectl exec xwing -- curl --connect-timeout 10 -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
command terminated with exit code 28

vm@ST-10-01:~/yamls$ kubectl exec tiefighter -- curl --connect-timeout 10 -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
vm@ST-10-01:~/yamls$
```

```shell
vm@ST-10-01:~/yamls$ kubectl exec tiefighter -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
Panic: deathstar exploded

goroutine 1 [running]:
main.HandleGarbage(0x2080c3f50, 0x2, 0x4, 0x425c0, 0x5, 0xa)
        /code/src/github.com/empire/deathstar/
        temp/main.go:9 +0x64
main.main()
        /code/src/github.com/empire/deathstar/
        temp/main.go:5 +0x85
```

```yaml
cat > allow-empire-in-namespace-cilium.yaml << EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-empire-in-namespace
spec:
  endpointSelector:
    matchLabels:
      org: empire
      class: deathstar
  ingress:
  - fromEndpoints:
    - matchLabels:
        org: empire
        class: tiefighter
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "POST"
          path: "/v1/request-landing"
  - fromEndpoints:
    - matchLabels:
        org: empire
        class: maintenance-droid
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "PUT"
          path: "/v1/exhaust-port"
EOF
```

```shell
vm@ST-10-01:~/yamls$ kubectl apply -f allow-empire-in-namespace-cilium.yaml
ciliumnetworkpolicy.cilium.io/allow-empire-in-namespace created
```

## Hubble Installation

```shell
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

```

```shell
cilium hubble port-forward
```
