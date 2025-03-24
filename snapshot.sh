#!/bin/bash

# Multipass VM Snapshot Script
# This script stops VMs, creates snapshots with the provided name, and optionally restarts them.
# Usage: ./snapshot.sh SNAPSHOT_NAME [--no-restart]

# Define VM instances
VMS=("control-plane-01" "worker-01" "worker-02" "worker-03")

# Check if snapshot name is provided
if [ $# -lt 1 ]; then
    echo "Error: No snapshot name provided"
    echo "Usage: $0 SNAPSHOT_NAME [--no-restart]"
    exit 1
fi

SNAPSHOT_NAME="$1"
RESTART_VMS=true

# Check for optional no-restart flag
if [ "$2" == "--no-restart" ]; then
    RESTART_VMS=false
fi

echo "===== Creating snapshots with name: $SNAPSHOT_NAME ====="

# Step 1: Stop all VMs
echo "Stopping all VMs..."
for vm in "${VMS[@]}"; do
    echo "Stopping $vm..."
    multipass stop "$vm"
    if [ $? -ne 0 ]; then
        echo "Error stopping $vm"
        exit 1
    fi
done

# Step 2: Take snapshots of all VMs
echo -e "\nCreating snapshots..."
for vm in "${VMS[@]}"; do
    echo "Creating snapshot of $vm as $SNAPSHOT_NAME..."
    multipass snapshot "$vm" -n "$SNAPSHOT_NAME"
    if [ $? -ne 0 ]; then
        echo "Error creating snapshot for $vm"
        exit 1
    fi
done

# Step 3: Verify snapshots
echo -e "\nVerifying snapshots..."
multipass list --snapshots

# Step 4: Restart VMs if needed
if [ "$RESTART_VMS" = true ]; then
    echo -e "\nRestarting VMs..."
    for vm in "${VMS[@]}"; do
        echo "Starting $vm..."
        multipass start "$vm"
        if [ $? -ne 0 ]; then
            echo "Error starting $vm"
            exit 1
        fi
    done
    
    echo -e "\nChecking VM status..."
    multipass list
else
    echo -e "\nVMs left in stopped state as requested."
fi

echo -e "\nSnapshot process completed successfully."