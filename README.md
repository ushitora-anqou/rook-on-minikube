# rook-ceph-dev

## Expected execution environment

- Minikube is already installed and kvm2 driver is enabled.
- CPU: >= 16 cores
- RAM: >= 32 GiB
- Disk: >= 100 GiB free

## Check that `rgw_enable_usage_log` in `rook-ceph-config` has no effect

Deploy Minikube, TopoLVM, Rook, and RGW.

```
$ git clone https://github.com/ushitora-anqou/rook-on-minikube.git
$ cd rook-on-minikube
$ git checkout rook-14737
$ git submodule update --init --recursive
$ make minikube/start
$ make minikube/setup-lvm
$ make topolvm/deploy
$ make -C rook build
$ make rook/load-dev-image IMAGE=build-36a6140b/ceph-amd64 # <--------- The image name will be different in your environment
$ make rook/deploy-cluster
$ make rook/deploy-ceph-object-store
```

Set `rgw_enable_usage_log` to `false` manually so that we can check if the setting persists.

```
$ minikube kubectl -- exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph config set client.rgw.my.store.a rgw_enable_usage_log false

$ minikube kubectl -- exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph config dump | grep rgw_enable_usage_log
client.rgw.my.store.a        advanced  rgw_enable_usage_log                   false           
```

Deploy a new rook-config-override ConfigMap which sets `rgw_enable_usage_log` to `false`.

```
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
```

Restart the Rook operator. `rgw_enable_usage_log` will revert to `true` after a while.

```
$ minikube kubectl -- rollout restart -n rook-ceph deploy/rook-ceph-operator
deployment.apps/rook-ceph-operator restarted

$ sleep 120

$ minikube kubectl -- exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph config dump | grep rgw_enable_usage_log
client.rgw.my.store.a        advanced  rgw_enable_usage_log                   true            
```
