#!/bin/bash

# Project directory to mount (if needed, only for control-plane)
PROJECT_DIR=$(pwd)
echo "Project directory that will be mounted: $PROJECT_DIR"

# QEMU instance configuration
QEMU_CPUS_CONTROL_PLANE="2"
QEMU_MEMORY_CONTROL_PLANE="8G"
QEMU_DISK_CONTROL_PLANE="20G"

QEMU_CPUS_WORKER="2"
QEMU_MEMORY_WORKER="4G"
QEMU_DISK_WORKER="20G"

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

# Function to create a QEMU instance
create_qemu_instance() {
  local name="$1"
  local cpus="$2"
  local memory="$3"
  local disk="$4"
  local cloud_init_file="$5"
  local mount_dir="$6" # Optional mount directory

  echo "Creating QEMU instance: $name"

  # Create a disk image
  qemu-img create -f qcow2 "$name.qcow2" "$disk"

  # Download the Ubuntu 24.04 cloud image
  wget -q "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img" -O "ubuntu-24.04-server-cloudimg-amd64.img"

  # Create a cloud-init ISO
  echo "$CLOUD_INIT_DATA" | cloud-localds "$cloud_init_file"

  # Run QEMU with necessary options
  qemu-system-x86_64 \
    -name "$name" \
    -m "$memory" \
    -smp "$cpus" \
    -drive file="$name.qcow2",format=qcow2 \
    -drive file="ubuntu-24.04-server-cloudimg-amd64.img",format=raw,if=virtio \
    -drive file="$cloud_init_file",format=raw,if=virtio \
    -netdev user,id=mynet0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=mynet0 \
    -nographic

  # Mount the project directory if provided (only for control plane)
  if [ -n "$mount_dir" ]; then
    echo "Mounting project directory $mount_dir to /home/ubuntu/k8s-project in $name"
    # This part needs to be handled inside the guest OS, not from host in QEMU.
    # We will install sshfs inside cloud-init and mount from inside.
    echo "#cloud-config" >> "$cloud_init_file"
    echo "package_update: true" >> "$cloud_init_file"
    echo "packages:" >> "$cloud_init_file"
    echo "  - sshfs" >> "$cloud_init_file"
    echo "runcmd:" >> "$cloud_init_file"
    echo "  - mkdir -p /home/ubuntu/k8s-project" >> "$cloud_init_file"
    echo "  - sshfs ubuntu@10.0.2.2:/home/ubuntu/k8s-project /home/ubuntu/k8s-project -o IdentityFile=/home/ubuntu/.ssh/id_ed25519 -o allow_other" >> "$cloud_init_file"
    echo "  - echo 'ubuntu ALL=(ALL) NOPASSWD: /usr/bin/fusermount' | sudo tee -a /etc/sudoers.d/sshfs" >> "$cloud_init_file"
    echo "  - echo 'Defaults !requiretty' | sudo tee -a /etc/sudoers.d/sshfs-no-tty" >> "$cloud_init_file"
    echo "  - echo '10.0.2.2 host.docker.internal' | sudo tee -a /etc/hosts" >> "$cloud_init_file"
  fi

  echo "QEMU instance $name created."
}

# Create control plane node
create_qemu_instance "control-plane-01" "$QEMU_CPUS_CONTROL_PLANE" "$QEMU_MEMORY_CONTROL_PLANE" "$QEMU_DISK_CONTROL_PLANE" "control-plane-01-cloud-init.iso" "$PROJECT_DIR"

# Create worker nodes
create_qemu_instance "worker-01" "$QEMU_CPUS_WORKER" "$QEMU_MEMORY_WORKER" "$QEMU_DISK_WORKER" "worker-01-cloud-init.iso" ""
create_qemu_instance "worker-02" "$QEMU_CPUS_WORKER" "$QEMU_MEMORY_WORKER" "$QEMU_DISK_WORKER" "worker-02-cloud-init.iso" ""
create_qemu_instance "worker-03" "$QEMU_CPUS_WORKER" "$QEMU_MEMORY_WORKER" "$QEMU_DISK_WORKER" "worker-03-cloud-init.iso" ""

echo "All QEMU instances created."
echo "To connect to control-plane-01: ssh ubuntu@localhost -p 2222"