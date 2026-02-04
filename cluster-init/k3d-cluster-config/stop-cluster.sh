#!/bin/bash

set -e

CLUSTERS=("cloud-a-cluster" "cloud-b-cluster-1")

echo "Stopping K3D Clusters"
echo "===================="

for cluster in "${CLUSTERS[@]}"; do
    echo ""
    echo "Stopping cluster: $cluster"
    
    if k3d cluster list | grep -q "$cluster"; then
        k3d cluster stop "$cluster"
        echo "✓ $cluster stopped"
    else
        echo "⚠ Cluster $cluster not found"
    fi
done

echo ""
echo "✓ All clusters stopped"
