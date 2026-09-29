KUBECTL=minikube kubectl --
ROOK_VERSION=v1.20.7
ROOK_EXAMPLES=https://raw.githubusercontent.com/rook/rook/$(ROOK_VERSION)/deploy/examples

.PHONY: help
help: ## Display this help.
	@awk '\
		BEGIN { \
			FS = ":.*"; \
			printf "\nUsage:\n  make \033[36m<target>\033[0m\n" \
		} \
		/^[/a-zA-Z_0-9-]+:.*?/ { \
			printf "  \033[36m%-15s\033[0m\n", $$1 \
		} \
		/^##@/ { \
			printf "\n\033[1m%s\033[0m\n", substr($$0, 5) \
		} ' \
		$(MAKEFILE_LIST)

##@ All

.PHONY: launch
launch: ## Launch all components.
	$(MAKE) minikube/start
	$(MAKE) minikube/setup-lvm
	$(MAKE) topolvm/deploy
	$(MAKE) rook/deploy-cluster
	$(MAKE) rook/deploy-ceph-object-store
	$(MAKE) rook/deploy-ceph-block-pool

##@ Minikube

.PHONY: minikube/start
minikube/start:
	minikube start --driver=kvm2 --nodes 1 --cpus 4 --memory 6g --disk-size=30g

.PHONY: minikube/stop
minikube/stop:
	minikube delete

.PHONY: minikube/setup-lvm
minikube/setup-lvm:
	minikube ssh -n minikube -- sudo truncate --size=20G backing_store
	minikube ssh -n minikube -- sudo losetup -f backing_store
	minikube ssh -n minikube -- sudo vgcreate myvg1 $$(minikube ssh -n minikube -- sudo losetup -j backing_store | cut -d':' -f1)

##@ TopoLVM

.PHONY: topolvm/deploy
topolvm/deploy:
	helm repo add topolvm https://topolvm.github.io/topolvm
	$(KUBECTL) apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.crds.yaml
	$(KUBECTL) create namespace topolvm-system || true
	$(KUBECTL) label namespace topolvm-system topolvm.io/webhook=ignore --overwrite
	$(KUBECTL) label namespace kube-system topolvm.io/webhook=ignore --overwrite
	helm upgrade --install --wait --timeout 10m --namespace=topolvm-system topolvm topolvm/topolvm --values manifests/topolvm-values.yaml

##@ Rook

.PHONY: rook/deploy-operator
rook/deploy-operator:
	$(KUBECTL) apply --server-side -f $(ROOK_EXAMPLES)/crds.yaml -f $(ROOK_EXAMPLES)/common.yaml -f $(ROOK_EXAMPLES)/csi-operator.yaml
	$(KUBECTL) wait --for=condition=Established crd --all --timeout=5m
	$(KUBECTL) apply -f $(ROOK_EXAMPLES)/operator.yaml
	$(KUBECTL) -n rook-ceph wait --for=condition=Available deploy/rook-ceph-operator --timeout=10m

.PHONY: rook/deploy-cluster
rook/deploy-cluster: rook/deploy-operator
	$(KUBECTL) apply -f manifests/cluster.yaml
	$(KUBECTL) apply -f $(ROOK_EXAMPLES)/toolbox.yaml
	$(KUBECTL) -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephcluster/rook-ceph --timeout=20m
	$(KUBECTL) -n rook-ceph wait --for=condition=Available deploy/rook-ceph-tools --timeout=10m

.PHONY: rook/deploy-ceph-object-store
rook/deploy-ceph-object-store:
	$(KUBECTL) apply -f manifests/object.yaml
	$(KUBECTL) -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephobjectstore/my-store --timeout=20m
	$(KUBECTL) -n rook-ceph rollout status deploy/rook-ceph-rgw-my-store-a --timeout=10m

.PHONY: rook/deploy-ceph-block-pool
rook/deploy-ceph-block-pool:
	$(KUBECTL) apply -f manifests/pool.yaml
	$(KUBECTL) -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephblockpool/replicapool --timeout=10m
