#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTERS=("cloud-a-cluster" "cloud-b-cluster-1")
MAX_RETRIES=30
RETRY_DELAY=2

echo "Starting cluster verification..."
echo "================================"

verify_cluster() {
    local cluster_name=$1
    local retry=0
    
    echo ""
    echo "Verifying cluster: $cluster_name"
    
    while [ $retry -lt $MAX_RETRIES ]; do
        if k3d cluster list | grep -q "$cluster_name"; then
            echo "  ✓ Cluster found"
            
            # Get kubeconfig
            k3d kubeconfig get "$cluster_name" > /dev/null 2>&1
            echo "  ✓ Kubeconfig accessible"
            
            # Check nodes
            local node_count=$(kubectl --context=k3d-"$cluster_name" get nodes --no-headers 2>/dev/null | wc -l)
            if [ "$node_count" -gt 0 ]; then
                echo "  ✓ Found $node_count nodes"
                
                # Check node status
                local ready_nodes=$(kubectl --context=k3d-"$cluster_name" get nodes --no-headers 2>/dev/null | grep -c "Ready" || true)
                if [ "$ready_nodes" -eq "$node_count" ]; then
                    echo "  ✓ All nodes are Ready"
                    return 0
                else
                    echo "  ⚠ Only $ready_nodes/$node_count nodes are Ready"
                fi
            fi
        fi
        
        retry=$((retry + 1))
        if [ $retry -lt $MAX_RETRIES ]; then
            echo "  Retrying... ($retry/$MAX_RETRIES)"
            sleep $RETRY_DELAY
        fi
    done
    
    echo "  ✗ Failed to verify cluster"
    return 1
}

all_verified=true
for cluster in "${CLUSTERS[@]}"; do
    if ! verify_cluster "$cluster"; then
        all_verified=false
    fi
done

echo ""
echo "================================"
if [ "$all_verified" = true ]; then
    echo "✓ All clusters verified successfully!"
    exit 0
else
    echo "✗ Some clusters failed verification"
    exit 1
fi
