#!/bin/bash

# Get the current directory as the project directory to mount
PROJECT_DIR=$(pwd)
echo "Project directory that will be mounted: $PROJECT_DIR"

# Create the control plane container with mounted project directory
echo "Creating control plane node with mounted project directory..."
lxc launch ubuntu:24.04 control-plane-01 -c user.user-data="$(cat cloud-init.yaml)"
lxc config set control-plane-01 limits.cpu 2
lxc config set control-plane-01 limits.memory 8GB
lxc config device set control-plane-01 root size 20GB
lxc config device add control-plane-01 k8s-project disk source="$PROJECT_DIR" path=/home/ubuntu/k8s-project

# Create worker containers
echo "Creating worker nodes..."
for node in worker-01 worker-02 worker-03; do
  lxc launch ubuntu:24.04 $node -c user.user-data="$(cat cloud-init.yaml)"
  lxc config set $node limits.cpu 2
  lxc config set $node limits.memory 4GB
  lxc config device set $node root size 20GB
done

echo "All instances created. Listing details:"
lxc list

echo "Configuration details for control-plane-01:"
lxc config device show control-plane-01

echo
echo "You can now access the control plane container and see your project at /home/ubuntu/k8s-project"
echo "To connect: lxc exec control-plane-01 -- /bin/bash"
