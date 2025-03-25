#!/bin/bash

# Get the current directory as the project directory to mount
PROJECT_DIR=$(pwd)
echo "Project directory that will be mounted: $PROJECT_DIR"

# Create the control plane container with mounted project directory
echo "Creating control plane node with mounted project directory..."
lxc launch ubuntu:24.04 control-plane-01 -c user.user-data="$(cat cloud-init.yaml)"
lxc config device override control-plane-01 root size=20GB
lxc config set control-plane-01 limits.cpu 2
lxc config set control-plane-01 limits.memory 8GB
lxc config device add control-plane-01 k8s-project disk source="$PROJECT_DIR" path=/home/ubuntu/k8s-project

# Create worker containers
echo "Creating worker nodes..."
for node in worker-01 worker-02 worker-03; do
  lxc launch ubuntu:24.04 $node -c user.user-data="$(cat cloud-init.yaml)"
  lxc config device override $node root size=20GB
  lxc config set $node limits.cpu 2
  lxc config set $node limits.memory 4GB
done

echo "All instances created. Listing details:"
lxc list

# Define the SSH key to be added
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJilzM4pUEiaCAw3CTdc2ikEsNCkeVwLxC+GVcFvlfV ubuntu"

# Append the SSH key to /home/ubuntu/.ssh/authorized_keys in each container
for container in control-plane-01 worker-01 worker-02 worker-03; do
  echo "Configuring SSH key in container $container..."
  lxc exec $container -- mkdir -p /home/ubuntu/.ssh
  lxc exec $container -- bash -c "echo '$SSH_KEY' >> /home/ubuntu/.ssh/authorized_keys"
done

echo
echo "Configuration details for control-plane-01:"
lxc config device show control-plane-01

echo
echo "You can now access the control plane container and see your project at /home/ubuntu/k8s-project"
echo "To connect: lxc exec control-plane-01 -- /bin/bash"
