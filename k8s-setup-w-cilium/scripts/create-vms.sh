#!/bin/bash

# Get the current directory as the project directory to mount
PROJECT_DIR=$(pwd)
echo "Project directory that will be mounted: $PROJECT_DIR"

# Create Multipass Instances
echo "Creating control plane node with mounted project directory..."
multipass launch --name control-plane-01 --cpus 2 --memory 8G --disk 20G 24.04 --cloud-init cloud-init.yaml --mount "$PROJECT_DIR":/home/ubuntu/k8s-project

echo "Creating worker nodes..."
multipass launch --name worker-01 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml 
multipass launch --name worker-02 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
multipass launch --name worker-03 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml

echo "All instances created. Listing details:"
multipass list

echo "Mount information for control-plane-01:"
multipass info control-plane-01 | grep Mount

echo
echo "You can now access your project directory on the control plane at /home/ubuntu/k8s-project"
echo "To connect to the control plane: multipass shell control-plane-01"