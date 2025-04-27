#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
MANIFEST_DIR="/etc/kubernetes/manifests"
MANIFEST_NAME="etcd.yaml"
LATEST_BACKUP=$(ls -t "${MANIFEST_DIR}/${MANIFEST_NAME}.bak-"* 2>/dev/null | head -n1)

# === FUNCTIONS ===
info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
ok()   { echo -e "\e[1;32m[OK]\e[0m $1"; }
err()  { echo -e "\e[1;31m[ERROR]\e[0m $1"; }

# === CHECK BACKUP ===
if [[ -z "${LATEST_BACKUP}" ]]; then
  err "No backup manifest found at ${MANIFEST_DIR}/${MANIFEST_NAME}.bak-*"
  exit 1
fi

# === RESTORE ORIGINAL MANIFEST ===
info "Restoring original manifest from backup: ${LATEST_BACKUP}"
cp "${LATEST_BACKUP}" "${MANIFEST_DIR}/${MANIFEST_NAME}"

# === WAIT FOR KUBELET ===
info "Waiting for kubelet to restart etcd pod with original data directory..."
sleep 15
sudo crictl ps -a | grep etcd || true

# === VALIDATE STATUS ===
info "Checking etcd health after rollback..."
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

info "Cluster status after rollback:"
kubectl get nodes
kubectl get pods -A

ok "Rollback complete. etcd now using original data-dir."
