# rook-ceph-dev

## Expected execution environment

- Minikube is already installed and kvm2 driver is enabled.
- CPU: >= 16 cores
- RAM: >= 32 GiB
- Disk: >= 100 GiB free

## Usage

Deploy Minikube, TopoLVM, Rook, and RGW.

```
$ git clone https://github.com/ushitora-anqou/rook-on-minikube.git
$ cd rook-on-minikube
$ git checkout rook-13511
$ git submodule update --init --recursive
$ make minikube/start
$ make minikube/setup-lvm
$ make topolvm/deploy
$ make -C rook build
$ make rook/load-dev-image IMAGE=build-36a6140b/ceph-amd64 # <--------- The image name will be different in your environment
$ make rook/deploy-cluster
$ make rook/deploy-ceph-object-store

$ cat manifests/rook-config-override.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: rook-config-override
  namespace: rook-ceph
data:
  config: |
    [global]
    rgw_enable_usage_log = false

$ minikube kubectl -- apply -f manifests/rook-config-override.yaml 
Warning: resource configmaps/rook-config-override is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
configmap/rook-config-override configured

$ minikube kubectl -- get cm -n rook-ceph rook-config-override -o yaml
apiVersion: v1
data:
  config: |
    [global]
    rgw_enable_usage_log = false
kind: ConfigMap

... snip ...

$ minikube kubectl -- rollout restart -n rook-ceph deploy/rook-ceph-operator
deployment.apps/rook-ceph-operator restarted

$ minikube kubectl -- exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph config dump | grep rgw_enable_usage_log
client.rgw.my.store2.a        advanced  rgw_enable_usage_log                   true            
```
