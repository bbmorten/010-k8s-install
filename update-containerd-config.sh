#!/bin/bash

# Update containerd config.toml to enable insecure registry access
# Usage: sudo ./update-registry-config.sh [registry_host]

# Default to the control plane IP from inventory
REGISTRY_HOST=${1:-"192.168.48.131:5000"}
CONFIG_FILE="/etc/containerd/config.toml"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${CONFIG_FILE}.${TIMESTAMP}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Backup the original config
echo "Creating backup at $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Add registry configuration
echo "Updating containerd configuration for insecure registry: $REGISTRY_HOST"
cat > /tmp/registry_config.toml << EOL
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = ""

      [plugins."io.containerd.grpc.v1.cri".registry.auths]

      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."$REGISTRY_HOST".tls]
          insecure_skip_verify = true

      [plugins."io.containerd.grpc.v1.cri".registry.headers]

      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$REGISTRY_HOST"]
          endpoint = ["http://$REGISTRY_HOST"]
EOL

# Find the registry section in the config file
REGISTRY_LINE=$(grep -n "\[plugins.\"io.containerd.grpc.v1.cri\".registry\]" "$CONFIG_FILE" | cut -d: -f1)

if [ -n "$REGISTRY_LINE" ]; then
  # Find where the registry section ends
  NEXT_SECTION_LINE=$(tail -n +$((REGISTRY_LINE+1)) "$CONFIG_FILE" | grep -n "^\[" | head -1 | cut -d: -f1)
  if [ -n "$NEXT_SECTION_LINE" ]; then
    SECTION_END=$((REGISTRY_LINE + NEXT_SECTION_LINE - 1))
  else
    SECTION_END=$(wc -l < "$CONFIG_FILE")
  fi
  
  # Create new config file with updated registry section
  head -n $((REGISTRY_LINE-1)) "$CONFIG_FILE" > /tmp/new_config.toml
  cat /tmp/registry_config.toml >> /tmp/new_config.toml
  tail -n +$((SECTION_END+1)) "$CONFIG_FILE" >> /tmp/new_config.toml
else
  echo "Error: Couldn't find registry section in config file"
  exit 1
fi

# Test if the new config is valid
containerd config validate /tmp/new_config.toml > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: New configuration is invalid. Not applying changes."
  echo "Check /tmp/new_config.toml for issues."
  exit 1
fi

# Apply the new config
mv /tmp/new_config.toml "$CONFIG_FILE"
echo "Configuration updated successfully."
echo "Original configuration backed up to $BACKUP_FILE"
echo "You should now restart containerd: systemctl restart containerd"