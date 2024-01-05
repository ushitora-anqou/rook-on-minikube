# rook-ceph-dev

## Expected execution environment

- Minikube is already installed and kvm2 driver is enabled.
- CPU: >= 16 cores
- RAM: >= 32 GiB
- Disk: >= 100 GiB free

## Usage

`make help` is available.

```
make minikube/start
make minikube/setup-lvm
make topolvm/deploy

# Check if manifests/{operator.yaml,cluster.yaml} are expected ones before running the following commands.
make rook/deploy-cluster
make rook/deploy-ceph-object-store

make rook/delete-cluster # will delete ceph-object-store too

make rook/load-dev-image IMAGE=

make minikube/stop
```
