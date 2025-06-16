#!/bin/sh
set -e
# Docker Engine for Linux uninstallation script.
# This script removes Docker Engine, CLI, containerd, and related configuration.
# Run as root or with sudo privileges.

# Remove Docker packages
apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras docker-compose docker || true
apt-get autoremove -y || true
apt-get autoclean -y || true

# Stop Docker service if running
systemctl stop docker || true
systemctl disable docker || true

# Remove Docker config and data directories
rm -rf /etc/docker /var/lib/docker /var/lib/containerd /var/run/docker.sock

# Remove Docker group if exists
if getent group docker > /dev/null 2>&1; then
    groupdel docker || true
fi

# Remove users from docker group (optional, comment out if not desired)
# for user in $(getent group docker | awk -F: '{print $4}' | tr ',' ' '); do
#     deluser "$user" docker || true
# done

# Remove Docker apt repository and GPG key
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc

# Update apt cache
apt-get update -y || true

echo "Docker Engine and related components have been uninstalled."
