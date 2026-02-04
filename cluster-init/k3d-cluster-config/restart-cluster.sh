#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTERS=("cloud-a-cluster" "cloud-b-cluster-1")

echo "Restarting K3D Clusters"
echo "======================"

for cluster in "${CLUSTERS[@]}"; do
    echo ""
    echo "Restarting cluster: $cluster"
    
    if k3d cluster list | grep -q "$cluster"; then
        echo "Stopping $cluster..."
        k3d cluster stop "$cluster"
        sleep 2
        echo "Starting $cluster..."
        k3d cluster start "$cluster"
        echo "✓ $cluster restarted"
    else
        echo "⚠ Cluster $cluster not found"
    fi
done

echo ""
echo "Verifying clusters..."
"$SCRIPT_DIR/verify-clusters.sh"
