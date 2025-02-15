KUBECTL=minikube kubectl --

##@ Minikube

.PHONY: minikube/setup
minikube/setup:
	$(MAKE) minikube/stop
	$(MAKE) minikube/start
	$(MAKE) minikube/setup-lvm
	$(MAKE) topolvm/deploy
	$(MAKE) minikube/load-image
	$(MAKE) rook/deploy-cluster
	$(KUBECTL) get pod -n rook-ceph -w

.PHONY: minikube/start
minikube/start:
	minikube start --driver=kvm2 --nodes 1 --cpus 4 --memory 8g --disk-size=30g

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
	$(KUBECTL) label namespace topolvm-system topolvm.io/webhook=ignore
	$(KUBECTL) label namespace kube-system topolvm.io/webhook=ignore
	helm install --namespace=topolvm-system topolvm topolvm/topolvm --values manifests/topolvm-values.yaml || true
#	$(KUBECTL) get pod -n topolvm-system -w

.PHONY: minikube/load-image
minikube/load-image:
	minikube image load result

##@ Rook

.PHONY: rook/deploy-cluster
rook/deploy-cluster:
	$(KUBECTL) apply -f rook/deploy/examples/common.yaml
	$(KUBECTL) apply -f rook/deploy/examples/crds.yaml
	$(KUBECTL) apply -f rook/deploy/examples/operator.yaml
	$(KUBECTL) apply -f manifests/cluster.yaml
	$(KUBECTL) apply -f manifests/toolbox.yaml

.PHONY: rook/deploy-ceph-object-store
rook/deploy-ceph-object-store:
	$(KUBECTL) apply -f manifests/object.yaml
	$(KUBECTL) get pod -n rook-ceph -w
