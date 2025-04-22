#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
SNAPSHOT_PATH="/home/vm/tmp/etcd-snapshot.db"
MANIFEST_PATH="/etc/kubernetes/manifests/etcd.yaml"
NODE_NAME="$(hostname)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESTORE_DIR="/var/lib/etcd-restore-${TIMESTAMP}"
CLUSTER_TOKEN="etcd-cluster-${TIMESTAMP}"

# === FUNCTIONS ===
info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
ok()   { echo -e "\e[1;32m[OK]\e[0m $1"; }
err()  { echo -e "\e[1;31m[ERROR]\e[0m $1"; }

# === CHECKS ===
[[ -f "${SNAPSHOT_PATH}" ]] || { err "Snapshot file not found: ${SNAPSHOT_PATH}"; exit 1; }
[[ -f "${MANIFEST_PATH}" ]] || { err "etcd manifest not found: ${MANIFEST_PATH}"; exit 1; }

# === STEP 1: Restore to a new directory ===
info "Restoring snapshot to: ${RESTORE_DIR}"
ETCDCTL_API=3 etcdctl snapshot restore "${SNAPSHOT_PATH}" \
  --data-dir="${RESTORE_DIR}" \
  --name="${NODE_NAME}" \
  --initial-cluster="${NODE_NAME}=https://127.0.0.1:2380" \
  --initial-cluster-token="${CLUSTER_TOKEN}" \
  --initial-advertise-peer-urls="https://127.0.0.1:2380"
ok "Snapshot restored successfully."

# === STEP 2: Backup and update the manifest ===
BACKUP_PATH="${MANIFEST_PATH}.bak-${TIMESTAMP}"
info "Backing up manifest to: ${BACKUP_PATH}"
cp "${MANIFEST_PATH}" "${BACKUP_PATH}"

info "Updating --data-dir in manifest to: ${RESTORE_DIR}"
sed -i "s|--data-dir=.*|--data-dir=${RESTORE_DIR}|" "${MANIFEST_PATH}"

ok "Manifest updated. Kubelet will automatically restart etcd using new data."

# === STEP 3: Monitor etcd ===
info "Waiting for etcd pod to restart..."
sleep 15
sudo crictl ps -a | grep etcd || true

# === STEP 4: Validate cluster status ===
info "Checking etcd health..."
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

info "Cluster status:"
kubectl get nodes
kubectl get pods -A

ok "Restore process complete. Backup of original manifest: ${BACKUP_PATH}"
