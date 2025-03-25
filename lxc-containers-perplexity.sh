#!/bin/bash

# Convert these multipass instances to lxc instances. Instances should be ready for ansible. 
# 
# 
# --- create-instances.sh
# #!/bin/bash
# 
# # Get the current directory as the project directory to mount
# PROJECT_DIR=$(pwd)
# echo "Project directory that will be mounted: $PROJECT_DIR"
# 
# # Create Multipass Instances
# echo "Creating control plane node with mounted project directory..."
# multipass launch --name control-plane-01 --cpus 2 --memory 8G --disk 20G 24.04 --cloud-init cloud-init.yaml --mount "$PROJECT_DIR":/home/ubuntu/k8s-project
# 
# echo "Creating worker nodes..."
# multipass launch --name worker-01 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml 
# multipass launch --name worker-02 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
# multipass launch --name worker-03 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
# 
# echo "All instances created. Listing details:"
# multipass list
# 
# echo "Mount information for control-plane-01:"
# multipass info control-plane-01 | grep Mount
# 
# echo
# echo "You can now access your project directory on the control plane at /home/ubuntu/k8s-project"
# echo "To connect to the control plane: multipass shell control-plane-01"
# 
# ---cloud-init.yaml
# users:
#   - default
#   - name: ubuntu
#     sudo: ALL=(ALL) NOPASSWD:ALL
#     ssh_authorized_keys:
#       - |
#         ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJilzM4pUEiaCAw3CTdc2ikEsNCkeVwLxC+GVcFvlfV ubuntu

# Define project directory to mount
PROJECT_DIR=$(pwd)
echo "Project directory that will be mounted: $PROJECT_DIR"

# Create LXC containers
echo "Creating control plane container with mounted project directory..."
lxc launch ubuntu:24.04 control-plane-01 -c limits.cpu=2 -c limits.memory=8GB -c root.size=20GB
lxc config device add control-plane-01 k8s-project disk source="$PROJECT_DIR" path=/home/ubuntu/k8s-project

echo "Creating worker containers..."
for worker in worker-01 worker-02 worker-03; do
  lxc launch ubuntu:24.04 $worker -c limits.cpu=2 -c limits.memory=4GB -c root.size=20GB
done

echo "Configuring SSH keys for Ansible..."
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJilzM4pUEiaCAw3CTdc2ikEsNCkeVwLxC+GVcFvlfV ubuntu"
for container in control-plane-01 worker-01 worker-02 worker-03; do
  lxc exec $container -- bash -c "mkdir -p /home/ubuntu/.ssh && echo '$SSH_KEY' >> /home/ubuntu/.ssh/authorized_keys && chmod 600 /home/ubuntu/.ssh/authorized_keys"
done

echo "Setting up static IPs for Ansible inventory..."
lxc network attach lxdbr0 control-plane-01 eth0 eth0
lxc config device set control-plane-01 eth0 ipv4.address 10.0.0.101

for i in {1..3}; do
  lxc network attach lxdbr0 worker-0$i eth0 eth0
  lxc config device set worker-0$i eth0 ipv4.address 10.0.0.10$i
done

echo "Restarting containers to apply network settings..."
for container in control-plane-01 worker-01 worker-02 worker-03; do
  lxc restart $container
done

echo "All LXC containers created and configured."
echo "Control plane accessible at IP: 10.0.0.101"
echo "Worker nodes accessible at IPs: 10.0.0.102, 10.0.0.103, 10.0.0.104"
