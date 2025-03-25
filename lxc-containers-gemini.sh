#!/bin/bash

# Project directory to mount (if needed, only for control-plane)
PROJECT_DIR=$(pwd)
echo "Project directory that will be mounted: $PROJECT_DIR"

# LXC instance configuration
LXC_CPUS_CONTROL_PLANE="2"
LXC_MEMORY_CONTROL_PLANE="8G"
LXC_DISK_CONTROL_PLANE="20G"

LXC_CPUS_WORKER="2"
LXC_MEMORY_WORKER="4G"
LXC_DISK_WORKER="20G"

# Cloud-init data (same as your cloud-init.yaml)
CLOUD_INIT_DATA=$(cat <<EOF
#cloud-config
users:
  - default
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - |
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJilzM4pUEiaCAw3CTdc2ikEsNCkeVwLxC+GVcFvlfV ubuntu
EOF
)

# Function to create an LXC instance
create_lxc_instance() {
  local name="$1"
  local cpus="$2"
  local memory="$3"
  local disk="$4"
  local mount_dir="$5" # Optional mount directory

  echo "Creating LXC instance: $name"

  # Create the LXC container
  lxc launch ubuntu:24.04 "$name" -c limits.cpu="$cpus" -c limits.memory="$memory" -c limits.disk="$disk"

  # Configure cloud-init
  lxc file push - <<EOF "$name/etc/cloud/cloud.cfg.d/90_custom.cfg"
$CLOUD_INIT_DATA
EOF

  # Mount the project directory if provided (only for control plane)
  if [ -n "$mount_dir" ]; then
    echo "Mounting project directory $mount_dir to /home/ubuntu/k8s-project in $name"
    lxc config device add "$name" k8s-project disk source="$mount_dir" path="/home/ubuntu/k8s-project"
  fi

  # Start the container
  lxc start "$name"

  # Get the IP address
  local ip_address=$(lxc list "$name" --format csv | awk -F',' 'NR==2 {print $6}')

  echo "LXC instance $name created. IP address: $ip_address"
}

# Create control plane node
create_lxc_instance "control-plane-01" "$LXC_CPUS_CONTROL_PLANE" "$LXC_MEMORY_CONTROL_PLANE" "$LXC_DISK_CONTROL_PLANE" "$PROJECT_DIR"

# Create worker nodes
create_lxc_instance "worker-01" "$LXC_CPUS_WORKER" "$LXC_MEMORY_WORKER" "$LXC_DISK_WORKER" ""
create_lxc_instance "worker-02" "$LXC_CPUS_WORKER" "$LXC_MEMORY_WORKER" "$LXC_DISK_WORKER" ""
create_lxc_instance "worker-03" "$LXC_CPUS_WORKER" "$LXC_MEMORY_WORKER" "$LXC_DISK_WORKER" ""

echo "All LXC instances created."
echo "You can connect to the control plane using its IP address."
echo "To get the IP of a container, use: lxc list <container_name>"