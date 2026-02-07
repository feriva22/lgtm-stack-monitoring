# Configuration
PROFILE ?= cloud-a-cluster-1
PROFILES := cloud-a-cluster-1 cloud-b-cluster-1
NODES = 2
CPUS = 4
MEMORY = 8192

.PHONY: start stop delete status clean help setup-user-kubeconfig start-all stop-all delete-all

help:
	@echo "Usage: make [start|stop|delete|status|clean|setup-user-kubeconfig]"
	@echo ""
	@echo "Targets:"
	@echo "  start                   - Start minikube cluster (default: cloud-a-cluster-1)"
	@echo "  start-all               - Start all profiles: $(PROFILES)"
	@echo "  setup-user-kubeconfig   - Copy kubeconfig and certs to user's home directory"
	@echo "  status                  - Show cluster status"
	@echo "  stop                    - Stop the cluster"
	@echo "  stop-all                - Stop all profiles"
	@echo "  delete                  - Delete the cluster"
	@echo "  delete-all              - Delete all profiles"
	@echo "  clean                   - Delete cluster and prune networks"
	@echo ""
	@echo "Examples:"
	@echo "  make start                         # Start default cluster"
	@echo "  make start PROFILE=cloud-b-cluster-1  # Start specific profile"
	@echo "  make start-all                     # Start all profiles"

registry-mirror:
	@echo "Configuring registry mirror for Minikube profile $(PROFILE)..."
	sudo docker run -d --name docker-proxy \
  		-p 3128:3128 \
  		-e ENABLE_MANIFEST_CACHE=true \
		-e DISABLE_IPV6=true \
  		-v $(pwd)/docker_mirror_cache:/docker_mirror_cache \
       	-v $(pwd)/docker_mirror_certs:/ca \
  		rpardini/docker-registry-proxy:amd64-latest || true
	@echo "Registry mirror configured."
	@echo "Mirroring the cert into the minikube ssl certs..."
	sudo mkdir -p /root/.minikube/files/etc/ssl/certs \
	&& sudo cp $(pwd)/docker_mirror_certs/ca.crt /root/.minikube/files/etc/ssl/certs/docker_registry_proxy.crt
	@echo "Cert copied."

delete-registry-mirror:
	@echo "Removing registry mirror..."
	sudo docker rm -f docker-proxy || true
	@echo "Registry mirror removed."

start:

	@echo "Starting Minikube cluster $(PROFILE)..."
	sudo minikube start -p $(PROFILE) \
		--nodes=$(NODES) \
		--cpus=$(CPUS) \
		--memory=$(MEMORY) \
		--driver=docker \
		--force \
		--docker-env HTTP_PROXY=http://feri-devops-machine.taild55be.ts.net:3128 \
		--docker-env HTTPS_PROXY=http://feri-devops-machine.taild55be.ts.net:3128 \
		--docker-env NO_PROXY="localhost,127.0.0.1,10.96.0.0/12,100.90.113.0/24" \
		--insecure-registry="100.90.113.0/24" \
		--wait=all
	@echo "Enable addons..."
	sudo minikube addons enable ingress -p $(PROFILE)
	sudo minikube addons enable metrics-server -p $(PROFILE)
	@ echo "Disable default storageclass..."
	sudo minikube addons disable storage-provisioner -p $(PROFILE)
	sudo minikube addons disable default-storageclass -p $(PROFILE)
	@ echo "Enable volume snapshot and csi-hostpath-driver addons to support multi-node ..."
	sudo minikube addons enable volumesnapshots -p $(PROFILE)
	sudo minikube addons enable csi-hostpath-driver -p $(PROFILE)
	@ echo "Set the storageclass as default..."
	sudo minikube -p $(PROFILE) -- patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

	@echo "Cluster is ready. 2 nodes running with registry mirrors configured."
	@$(MAKE) setup-user-kubeconfig

start-all:
	@echo "Starting all profiles: $(PROFILES)"
	@for profile in $(PROFILES); do \
		echo "Starting $$profile..."; \
		$(MAKE) start PROFILE=$$profile; \
	done
	@echo "All clusters started!"

setup-user-kubeconfig:
	@echo "Setting up kubeconfig for current user..."
	@mkdir -p $(HOME)/.kube
	@mkdir -p $(HOME)/.minikube/profiles/$(PROFILE)
	@sudo cp /root/.kube/config $(HOME)/.kube/config.$(PROFILE)
	@sudo cp /root/.minikube/ca.crt $(HOME)/.minikube/ca.crt
	@sudo cp /root/.minikube/ca.key $(HOME)/.minikube/ca.key
	@sudo cp /root/.minikube/profiles/$(PROFILE)/client.crt $(HOME)/.minikube/profiles/$(PROFILE)/client.crt
	@sudo cp /root/.minikube/profiles/$(PROFILE)/client.key $(HOME)/.minikube/profiles/$(PROFILE)/client.key
	@sudo chown -R $(USER):$(USER) $(HOME)/.kube/config.$(PROFILE) $(HOME)/.minikube
	@sed -i 's|/root/.minikube|$(HOME)/.minikube|g' $(HOME)/.kube/config.$(PROFILE)
	@chmod 600 $(HOME)/.kube/config.$(PROFILE)
	@chmod 644 $(HOME)/.minikube/ca.crt
	@chmod 600 $(HOME)/.minikube/ca.key
	@chmod 644 $(HOME)/.minikube/profiles/$(PROFILE)/client.crt
	@chmod 600 $(HOME)/.minikube/profiles/$(PROFILE)/client.key
	@echo "Kubeconfig saved to: $(HOME)/.kube/config.$(PROFILE)"
	@echo "Certificates copied to: $(HOME)/.minikube"
	@echo "To use it, set: export KUBECONFIG=$(HOME)/.kube/config.$(PROFILE)"

status:
	sudo minikube status -p $(PROFILE)
	kubectl get nodes --context $(PROFILE)

pause:
	sudo minikube pause -p $(PROFILE)
	@echo "Cluster $(PROFILE) paused."

stop:
	sudo minikube stop -p $(PROFILE)

stop-all:
	@echo "Stopping all profiles: $(PROFILES)"
	@for profile in $(PROFILES); do \
		echo "Stopping $$profile..."; \
		sudo minikube stop -p $$profile || true; \
	done

delete:
	sudo minikube delete -p $(PROFILE)

delete-all:
	@echo "Deleting all profiles: $(PROFILES)"
	@for profile in $(PROFILES); do \
		echo "Deleting $$profile..."; \
		sudo minikube delete -p $$profile || true; \
	done

clean: delete
	@docker network prune -f