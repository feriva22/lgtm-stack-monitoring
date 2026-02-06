.PHONY: help create-all create-cloud-a create-cloud-b verify-clusters start stop restart delete-all delete-cloud-a delete-cloud-b status logs

SCRIPT_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
CLOUD_A_CONFIG := $(SCRIPT_DIR)k3d-config-cloud-source-a.yaml
CLOUD_B_CONFIG := $(SCRIPT_DIR)k3d-config-cloud-source-b.yaml
CLOUD_A_CLUSTER := cloud-a-cluster-1
CLOUD_B_CLUSTER := cloud-b-cluster-1

help:
	@echo "K3D Cluster Management"
	@echo "====================="
	@echo "Available targets:"
	@echo "  make create-private-repository - Create a private Docker registry"
	@echo "  make create-all         - Create all clusters (cloud-a and cloud-b)"
	@echo "  make create-cloud-a     - Create cloud-a cluster only"
	@echo "  make create-cloud-b     - Create cloud-b cluster only"
	@echo "  make verify-clusters    - Verify all clusters are running"
	@echo "  make start              - Start all stopped clusters"
	@echo "  make stop               - Stop all running clusters"
	@echo "  make restart            - Restart all clusters"
	@echo "  make status             - Show status of all clusters"
	@echo "  make logs               - Show logs for all clusters"
	@echo "  make delete-all         - Delete all clusters"
	@echo "  make delete-cloud-a     - Delete cloud-a cluster only"
	@echo "  make delete-cloud-b     - Delete cloud-b cluster only"

create-private-repository:
	@echo "Creating private Docker registry..."
	k3d registry create docker-io -p 5000 --proxy-remote-url https://registry-1.docker.io -v ~/.local/share/docker-io-registry:/var/lib/registry || true
	k3d registry create quay-io -p 5001 --proxy-remote-url https://quay.io -v ~/.local/share/quay-io-registry:/var/lib/registry || true
	docker network connect k3d-$(CLOUD_A_CLUSTER) k3d-docker-io || true
	docker network connect k3d-$(CLOUD_A_CLUSTER) k3d-quay-io || true
	docker network connect k3d-$(CLOUD_B_CLUSTER) k3d-docker-io || true
	docker network connect k3d-$(CLOUD_B_CLUSTER) k3d-quay-io || true

	@echo "✓ Private Docker registry created"

create-all: create-cloud-a create-cloud-b verify-clusters
	@echo "✓ All clusters created successfully!"

create-cloud-a:
	@echo "Creating cloud-a cluster..."
	k3d cluster create --config $(CLOUD_A_CONFIG)
	@echo "✓ Cloud-a cluster created"

create-cloud-b:
	@echo "Creating cloud-b cluster..."
	k3d cluster create --config $(CLOUD_B_CONFIG)
	@echo "✓ Cloud-b cluster created"

verify-clusters:
	@echo "Verifying cluster creation..."
	@./$(SCRIPT_DIR)verify-clusters.sh

start:
	@echo "Starting all clusters..."
	k3d cluster start $(CLOUD_A_CLUSTER) || true
	k3d cluster start $(CLOUD_B_CLUSTER) || true
	@echo "✓ Clusters started"

stop:
	@echo "Stopping all clusters..."
	k3d cluster stop $(CLOUD_A_CLUSTER) || true
	k3d cluster stop $(CLOUD_B_CLUSTER) || true
	@echo "✓ Clusters stopped"

restart: stop start
	@echo "✓ Clusters restarted"

status:
	@echo "Cluster Status:"
	@echo "==============="
	k3d cluster list

logs:
	@echo "Getting logs for all clusters..."
	@echo "Cloud-A logs:"
	k3d logs $(CLOUD_A_CLUSTER) || true
	@echo ""
	@echo "Cloud-B logs:"
	k3d logs $(CLOUD_B_CLUSTER) || true

delete-all: delete-cloud-a delete-cloud-b
	@echo "✓ All clusters deleted"

delete-cloud-a:
	@echo "Deleting cloud-a cluster..."
	k3d cluster delete $(CLOUD_A_CLUSTER) || echo "Cluster not found"
	@echo "✓ Cloud-a cluster deleted"

delete-cloud-b:
	@echo "Deleting cloud-b cluster..."
	k3d cluster delete $(CLOUD_B_CLUSTER) || echo "Cluster not found"
	@echo "✓ Cloud-b cluster deleted"
