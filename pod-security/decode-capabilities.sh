#!/bin/bash

# Check if a pod name is passed
if [ -z "$1" ]; then
  echo "Usage: $0 <pod-name>"
  exit 1
fi

POD_NAME=$1

# Extract CapEff hex value from /proc/1/status inside the container
CAPEFF_HEX=$(kubectl exec "$POD_NAME" -- cat /proc/1/status | grep CapEff | awk '{print $2}')

# Check if we successfully retrieved the capability field
if [ -z "$CAPEFF_HEX" ]; then
  echo "Failed to retrieve CapEff from pod: $POD_NAME"
  exit 2
fi

# Display raw CapEff value
echo "CapEff (raw): $CAPEFF_HEX"

# Decode capabilities using capsh
echo "Decoded capabilities:"
capsh --decode=0x$CAPEFF_HEX
