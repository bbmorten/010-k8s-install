#!/bin/bash
# Script to check and resolve apt lock issues
# Use with caution - only run this when you're sure there are no active apt operations

# Check for lock processes
echo "Checking for processes holding apt locks..."
LOCK_PROCESSES=$(lsof /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock 2>/dev/null)

if [ -n "$LOCK_PROCESSES" ]; then
    echo "The following processes are holding apt locks:"
    echo "$LOCK_PROCESSES"
    
    read -p "Would you like to kill these processes? (y/n): " KILL_PROCESSES
    if [[ "$KILL_PROCESSES" =~ ^[Yy]$ ]]; then
        echo "Killing processes holding apt locks..."
        for PID in $(echo "$LOCK_PROCESSES" | awk '{print $2}' | grep -v PID | sort -u); do
            echo "Killing process $PID..."
            sudo kill -9 "$PID"
        done
    else
        echo "Not killing processes. It's recommended to wait for them to complete."
        exit 0
    fi
else
    echo "No processes currently holding apt locks."
fi

echo "Checking if lock files exist..."

# List of lock files to check
LOCK_FILES=(
    "/var/lib/dpkg/lock-frontend"
    "/var/lib/apt/lists/lock"
    "/var/cache/apt/archives/lock"
    "/var/lib/dpkg/lock"
)

LOCKS_FOUND=0

for LOCK_FILE in "${LOCK_FILES[@]}"; do
    if [ -f "$LOCK_FILE" ]; then
        echo "Lock file exists: $LOCK_FILE"
        LOCKS_FOUND=1
    fi
done

if [ $LOCKS_FOUND -eq 0 ]; then
    echo "No lock files found."
    exit 0
fi

read -p "Would you like to remove the lock files? (y/n): " REMOVE_LOCKS
if [[ "$REMOVE_LOCKS" =~ ^[Yy]$ ]]; then
    echo "Removing lock files..."
    for LOCK_FILE in "${LOCK_FILES[@]}"; do
        if [ -f "$LOCK_FILE" ]; then
            echo "Removing $LOCK_FILE..."
            sudo rm -f "$LOCK_FILE"
        fi
    done
    
    echo "Reconfiguring dpkg..."
    sudo dpkg --configure -a
    
    echo "Updating apt..."
    sudo apt-get update
    
    echo "Lock files have been removed and dpkg reconfigured."
else
    echo "Not removing lock files. You may need to wait for ongoing processes to complete."
fi

exit 0