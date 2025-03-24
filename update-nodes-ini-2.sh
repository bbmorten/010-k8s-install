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

# Extract hosts from nodes.ini file
CONTROL_PLANE_HOSTS=$(grep -A1 "\[control_plane\]" "$NODES_INI_PATH" | tail -n1 | awk '{print $1}')
WORKER_HOSTS=$(grep -A10 "\[workers\]" "$NODES_INI_PATH" | grep -v "^\[" | grep -v "^$" | awk '{print $1}')

# Create mapping for VM names to inventory hosts based on order
# Assuming first VM is control plane, rest are workers
declare -a ALL_HOSTS
ALL_HOSTS=($CONTROL_PLANE_HOSTS $WORKER_HOSTS)

# Display detected hosts
echo "Detected hosts in inventory:"
echo "Control plane: $CONTROL_PLANE_HOSTS"
echo "Workers: $WORKER_HOSTS"
echo

# Display VMs from multipass
echo "Detected VMs from multipass:"
echo "$VM_INFO"
echo

# Prompt user for confirmation or custom mapping
echo "How would you like to proceed?"
echo "1) Auto-map VMs to hosts in order (first VM to first host, etc.)"
echo "2) Manually map each VM to a host"
read -p "Enter choice (1/2): " MAPPING_CHOICE

# Initialize an associative array for storing mappings
declare -A VM_TO_HOST_MAP

if [ "$MAPPING_CHOICE" = "1" ]; then
    # Auto-map VMs to hosts based on order
    VM_COUNT=0
    while read -r VM_NAME VM_IP; do
        if [ $VM_COUNT -lt ${#ALL_HOSTS[@]} ]; then
            VM_TO_HOST_MAP[$VM_NAME]=${ALL_HOSTS[$VM_COUNT]}
            echo "Auto-mapped $VM_NAME to ${ALL_HOSTS[$VM_COUNT]}"
            VM_COUNT=$((VM_COUNT+1))
        else
            echo "Warning: More VMs than hosts in inventory, skipping $VM_NAME"
        fi
    done <<< "$VM_INFO"
else
    # Manual mapping
    while read -r VM_NAME VM_IP; do
        echo "VM: $VM_NAME ($VM_IP)"
        echo "Available hosts: ${ALL_HOSTS[@]}"
        read -p "Enter host name to map to $VM_NAME (or 'skip' to ignore): " HOST_CHOICE
        
        if [ "$HOST_CHOICE" != "skip" ]; then
            # Verify the host exists in our list
            HOST_EXISTS=0
            for HOST in "${ALL_HOSTS[@]}"; do
                if [ "$HOST" = "$HOST_CHOICE" ]; then
                    HOST_EXISTS=1
                    break
                fi
            done
            
            if [ $HOST_EXISTS -eq 1 ]; then
                VM_TO_HOST_MAP[$VM_NAME]=$HOST_CHOICE
                echo "Mapped $VM_NAME to $HOST_CHOICE"
            else
                echo "Warning: $HOST_CHOICE not found in inventory, skipping $VM_NAME"
            fi
        else
            echo "Skipping $VM_NAME"
        fi
    done <<< "$VM_INFO"
fi

# Now update the inventory file based on the mappings
echo
echo "Updating IP addresses in $NODES_INI_PATH:"
echo "------------------------------------------"

# Read the existing nodes.ini file to memory
NODES_CONTENT=$(cat "$NODES_INI_PATH")

# Process each VM based on the mapping
while read -r VM_NAME VM_IP; do
    # Get the host mapped to this VM
    MAPPED_HOST="${VM_TO_HOST_MAP[$VM_NAME]}"
    
    # Skip if no mapping or invalid IP
    if [ -z "$MAPPED_HOST" ]; then
        echo "No mapping for $VM_NAME, skipping"
        continue
    fi
    
    # Skip if the VM_IP is not a valid IP
    if ! [[ $VM_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Warning: $VM_NAME has invalid IP: $VM_IP. Skipping."
        continue
    fi
    
    # Get the current IP from the file
    CURRENT_IP=$(grep -E "$MAPPED_HOST.*ansible_host" "$NODES_INI_PATH" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    # Update the IP in the file
    if [ -n "$CURRENT_IP" ]; then
        echo "Updating $MAPPED_HOST: $CURRENT_IP → $VM_IP"
        # Use a different delimiter for sed to avoid issues with IP addresses containing dots
        NODES_CONTENT=$(echo "$NODES_CONTENT" | sed "s/ansible_host=$CURRENT_IP/ansible_host=$VM_IP/g")
    else
        echo "Warning: Could not find ansible_host entry for $MAPPED_HOST"
    fi
done <<< "$VM_INFO"

# Write the updated content back to the file
echo "$NODES_CONTENT" > "$NODES_INI_PATH"

echo "------------------------------------------"
echo "Inventory file updated successfully"
echo "You can verify the changes by comparing with the backup: diff $NODES_INI_PATH $BACKUP_FILE"

# Make the script executable
chmod +x "$0"