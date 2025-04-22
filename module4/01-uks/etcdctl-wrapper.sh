#!/bin/bash

# === Configuration ===
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS="https://127.0.0.1:2379"
export ETCDCTL_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
export ETCDCTL_CERT="/etc/kubernetes/pki/etcd/server.crt"
export ETCDCTL_KEY="/etc/kubernetes/pki/etcd/server.key"

# === Check for command arguments ===
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <etcdctl arguments>"
  echo "Example: $0 endpoint health"
  exit 1
fi

# === Execute etcdctl with passed arguments ===
etcdctl "$@"
