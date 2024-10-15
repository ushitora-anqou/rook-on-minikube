# rook-ceph-dev

## Expected execution environment

- Minikube is already installed and kvm2 driver is enabled.
- CPU: >= 16 cores
- RAM: >= 32 GiB
- Disk: >= 100 GiB free

## Check that PDBs blocking all hosts can be created under some circumstances

```
$ make minikube/start
$ make minikube/setup-lvm
$ make topolvm/deploy
$ make rook/deploy-cluster
$ make rook/deploy-ceph-object-store
```

```
$ kubectl drain --ignore-daemonsets --delete-emptydir-data minikube-m02
$ kubectl cordon minikube-m03
$ kubectl delete -n rook-ceph pod rook-ceph-osd-4-64dbc84dd9-x8rgp

$ kubectl get pdb -n rook-ceph
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-mon-pdb                 N/A             1                 0                     13m
rook-ceph-osd-host-minikube       N/A             0                 0                     94s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     94s

$ kubectl uncordon minikube-m02

$ kubectl get pdb -n rook-ceph
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-mon-pdb                 N/A             1                 1                     14m
rook-ceph-osd-host-minikube       N/A             0                 0                     2m42s
rook-ceph-osd-host-minikube-m02   N/A             0                 0                     7s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     2m42s
```
