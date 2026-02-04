#!/bin/bash

set -e

CLUSTERS=("cloud-a-cluster" "cloud-b-cluster-1")

echo "Starting K3D Clusters"
echo "===================="

for cluster in "${CLUSTERS[@]}"; do
    echo ""
    echo "Starting cluster: $cluster"
    
    if k3d cluster list | grep -q "$cluster"; then
        k3d cluster start "$cluster"
        echo "✓ $cluster started"
    else
        echo "⚠ Cluster $cluster not found. Creating it..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        k3d cluster create --config "$SCRIPT_DIR/k3d-config-${cluster%-cluster}.yaml" || true
    fi
done

echo ""
echo "✓ All clusters started successfully"
