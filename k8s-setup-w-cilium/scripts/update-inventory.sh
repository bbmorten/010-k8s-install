#!/bin/bash

# Script to update the Ansible inventory nodes.ini file with Multipass VM IP addresses
# Usage: ./update-nodes-ini.sh [path_to_nodes_ini]

# Default path to nodes.ini if not provided as argument
NODES_INI_PATH="${1:-inventory/nodes.ini}"

# Check if nodes.ini file exists
if [ ! -f "$NODES_INI_PATH" ]; then
    echo "Error: Nodes file $NODES_INI_PATH not found!"
    echo "Usage: $0 [path_to_nodes_ini]"
    exit 1
fi

# Create backup of original file
BACKUP_FILE="${NODES_INI_PATH}.bak.$(date +%Y%m%d%H%M%S)"
cp "$NODES_INI_PATH" "$BACKUP_FILE"
echo "Created backup of original file: $BACKUP_FILE"

# Get VM information from multipass
VM_INFO=$(multipass list | awk '{if (NR>1) print $1, $3}')

# Check if we got any VM info
if [ -z "$VM_INFO" ]; then
    echo "Error: No Multipass VMs found or multipass command failed!"
    exit 1
fi

# Read the existing nodes.ini file to memory
NODES_CONTENT=$(cat "$NODES_INI_PATH")

# Process each VM
echo "Updating IP addresses in $NODES_INI_PATH:"
echo "------------------------------------------"

while read -r VM_NAME VM_IP; do
    # Check the hostname format in the inventory file - with or without dashes
    if grep -q "$VM_NAME" "$NODES_INI_PATH"; then
        # VM name exists exactly as is in the file
        HOST_FORMAT="$VM_NAME"
    elif grep -q "${VM_NAME//-/}" "$NODES_INI_PATH"; then
        # VM name without dashes exists in the file
        HOST_FORMAT="${VM_NAME//-/}"
    elif grep -q "${VM_NAME//-/_}" "$NODES_INI_PATH"; then
        # VM name with dashes replaced by underscores exists in the file
        HOST_FORMAT="${VM_NAME//-/_}"
    else
        echo "Warning: No matching host entry found for VM $VM_NAME"
        continue
    fi

    # Get the current IP from the file
    CURRENT_IP=$(grep -E "$HOST_FORMAT.*ansible_host" "$NODES_INI_PATH" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    # Skip if the VM_IP is not a valid IP (sometimes multipass can show -- for stopped VMs)
    if ! [[ $VM_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Warning: $VM_NAME has invalid IP: $VM_IP. Skipping."
        continue
    fi
    
    # Update the IP in the file
    if [ -n "$CURRENT_IP" ]; then
        echo "Updating $HOST_FORMAT: $CURRENT_IP → $VM_IP"
        # Use a different delimiter for sed to avoid issues with IP addresses containing dots
        NODES_CONTENT=$(echo "$NODES_CONTENT" | sed "s/ansible_host=$CURRENT_IP/ansible_host=$VM_IP/g")
    else
        echo "Warning: Could not find ansible_host entry for $HOST_FORMAT"
    fi
done <<< "$VM_INFO"

# Write the updated content back to the file
echo "$NODES_CONTENT" > "$NODES_INI_PATH"

echo "------------------------------------------"
echo "Inventory file updated successfully"
echo "You can verify the changes by comparing with the backup: diff $NODES_INI_PATH $BACKUP_FILE"

# Make the script executable
chmod +x "$0"