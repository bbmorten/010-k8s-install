#!/bin/bash

# Variables
NAMESPACE=foo
SECRET_NAME=example-tls
CERT_FILE=tls.crt
KEY_FILE=tls.key
COMMON_NAME=test-ingress.example.com

echo "🔐 Generating self-signed TLS certificate for CN=$COMMON_NAME..."

# Generate self-signed certificate and key using OpenSSL
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $KEY_FILE \
  -out $CERT_FILE \
  -subj "/CN=$COMMON_NAME/O=Self-Signed"

# Create namespace if it doesn't exist
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

echo "📦 Creating Kubernetes TLS secret: $SECRET_NAME in namespace: $NAMESPACE"

# Create the TLS secret in Kubernetes
kubectl create secret tls $SECRET_NAME \
  --cert=$CERT_FILE \
  --key=$KEY_FILE \
  -n $NAMESPACE

# Verify
echo "🔍 Secret created:"
kubectl get secret $SECRET_NAME -n $NAMESPACE

# Optional cleanup of cert files
# rm -f $CERT_FILE $KEY_FILE

echo "✅ Done!"
