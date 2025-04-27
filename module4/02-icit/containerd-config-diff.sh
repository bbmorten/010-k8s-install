#!/bin/bash
#
# containerd-config-diff.sh
# Script to collect and compare containerd config.toml files across nodes
#

# Configuration
NODES_LIST="$1"  # First argument should be a space-separated list of node hostnames or IPs
SSH_USER="${2:-root}"  # Second argument is SSH user (default: root)
SSH_KEY="${3:-$HOME/git-msp/010-k8s-install/multipass-ssh-key}"  # Third argument is SSH key (default: ~/git-msp/010-k8s-install/multipass-ssh-key)
WORK_DIR="/tmp/containerd-diff-$$"  # Temporary working directory with PID to avoid conflicts

# Check if nodes list is provided
if [ -z "$NODES_LIST" ]; then
  echo "Error: Please provide a space-separated list of node hostnames or IPs as the first argument."
  echo "Usage: $0 \"node1 node2 node3\" [ssh_user] [ssh_key_path]"
  exit 1
fi

# Create working directory
mkdir -p "$WORK_DIR"
echo "Creating temporary directory: $WORK_DIR"

# Collect configs from all nodes
echo "Collecting containerd configs from nodes..."
for NODE in $NODES_LIST; do
  echo "Checking node: $NODE"
  
  # Check if containerd config exists
  if ssh -i "$SSH_KEY" "$SSH_USER@$NODE" "test -f /etc/containerd/config.toml"; then
    echo "  - Config found, copying..."
    # Copy the config.toml file
    scp -i "$SSH_KEY" "$SSH_USER@$NODE:/etc/containerd/config.toml" "$WORK_DIR/$NODE-config.toml" > /dev/null
    echo "  - Config saved to $WORK_DIR/$NODE-config.toml"
  else
    echo "  - No config.toml found on node $NODE"
    # Create an empty file to note the absence
    echo "# No containerd config.toml found on this node" > "$WORK_DIR/$NODE-config.toml"
  fi
done

# Find a reference config (first one with content)
REFERENCE_CONFIG=""
for NODE in $NODES_LIST; do
  if [ -s "$WORK_DIR/$NODE-config.toml" ] && ! grep -q "No containerd config.toml found" "$WORK_DIR/$NODE-config.toml"; then
    REFERENCE_CONFIG="$WORK_DIR/$NODE-config.toml"
    REFERENCE_NODE="$NODE"
    break
  fi
done

if [ -z "$REFERENCE_CONFIG" ]; then
  echo "Error: No valid containerd config.toml found on any node."
  exit 1
fi

echo -e "\n========================================"
echo "Using $REFERENCE_NODE as reference configuration"
echo "========================================\n"

# Compare each config to the reference
for NODE in $NODES_LIST; do
  # Skip comparison with itself
  if [ "$NODE" = "$REFERENCE_NODE" ]; then
    continue
  fi

  CONFIG_FILE="$WORK_DIR/$NODE-config.toml"
  
  # Check if the file exists and has content
  if [ -s "$CONFIG_FILE" ] && ! grep -q "No containerd config.toml found" "$CONFIG_FILE"; then
    echo "Comparing $REFERENCE_NODE with $NODE:"
    echo "----------------------------------------"
    
    # Use diff to compare the configs
    if diff -u "$REFERENCE_CONFIG" "$CONFIG_FILE" > "$WORK_DIR/diff-$NODE.txt"; then
      echo "No differences found."
    else
      # Show colorized diff if colordiff is available
      if command -v colordiff &> /dev/null; then
        colordiff -u "$REFERENCE_CONFIG" "$CONFIG_FILE" | head -n 100
        LINES=$(wc -l < "$WORK_DIR/diff-$NODE.txt")
        if [ "$LINES" -gt 100 ]; then
          echo -e "\n... ($(($LINES - 100)) more lines) ..."
        fi
      else
        diff -u "$REFERENCE_CONFIG" "$CONFIG_FILE" | head -n 100
        LINES=$(wc -l < "$WORK_DIR/diff-$NODE.txt")
        if [ "$LINES" -gt 100 ]; then
          echo -e "\n... ($(($LINES - 100)) more lines) ..."
        fi
      fi
      echo -e "\nFull diff saved to: $WORK_DIR/diff-$NODE.txt"
    fi
  else
    echo "Comparing $REFERENCE_NODE with $NODE:"
    echo "----------------------------------------"
    echo "No config.toml found on $NODE."
  fi
  echo -e "\n"
done

# Generate summary report
echo "========================================"
echo "SUMMARY REPORT"
echo "========================================"

# Check for missing configs
MISSING_CONFIGS=0
for NODE in $NODES_LIST; do
  if grep -q "No containerd config.toml found" "$WORK_DIR/$NODE-config.toml"; then
    echo "⚠️  $NODE: Missing containerd config.toml"
    MISSING_CONFIGS=1
  fi
done

if [ "$MISSING_CONFIGS" -eq 0 ]; then
  echo "✅ All nodes have containerd config.toml files."
fi

# Check for differences
DIFFERENT_CONFIGS=0
for NODE in $NODES_LIST; do
  if [ "$NODE" != "$REFERENCE_NODE" ] && [ -f "$WORK_DIR/diff-$NODE.txt" ] && [ -s "$WORK_DIR/diff-$NODE.txt" ]; then
    echo "❌ $NODE: Configuration differs from reference ($REFERENCE_NODE)"
    DIFFERENT_CONFIGS=1
  fi
done

if [ "$DIFFERENT_CONFIGS" -eq 0 ]; then
  echo "✅ All existing configs are identical to the reference config."
fi

echo -e "\nTemporary files stored in: $WORK_DIR"
echo "You can remove this directory when done with: rm -rf $WORK_DIR"

exit 0