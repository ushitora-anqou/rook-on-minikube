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

$ kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.00595  root default                                    
-7         0.00198      host minikube                               
 4    ssd  0.00099          osd.4              up   1.00000  1.00000
 5    ssd  0.00099          osd.5              up   1.00000  1.00000
-5         0.00198      host minikube-m02                           
 1    ssd  0.00099          osd.1              up   1.00000  1.00000
 3    ssd  0.00099          osd.3              up   1.00000  1.00000
-3         0.00198      host minikube-m03                           
 0    ssd  0.00099          osd.0              up   1.00000  1.00000
 2    ssd  0.00099          osd.2              up   1.00000  1.00000

$ kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE   RAW USE  DATA     OMAP  META     AVAIL     %USE  VAR   PGS  STATUS
 4    ssd  0.00099   1.00000  1 GiB  9.2 MiB  868 KiB   0 B  8.3 MiB  1015 MiB  0.90  0.83   46      up
 5    ssd  0.00099   1.00000  1 GiB  9.8 MiB  1.3 MiB   0 B  8.6 MiB  1014 MiB  0.96  0.90   43      up
 1    ssd  0.00099   1.00000  1 GiB   10 MiB  1.2 MiB   0 B  8.8 MiB  1014 MiB  0.98  0.91   31      up
 3    ssd  0.00099   1.00000  1 GiB   13 MiB  904 KiB   0 B   13 MiB  1011 MiB  1.31  1.22   58      up
 0    ssd  0.00099   1.00000  1 GiB   14 MiB  932 KiB   0 B   13 MiB  1010 MiB  1.38  1.28   50      up
 2    ssd  0.00099   1.00000  1 GiB  9.3 MiB  1.2 MiB   0 B  8.1 MiB  1015 MiB  0.91  0.85   39      up
                       TOTAL  6 GiB   66 MiB  6.4 MiB   0 B   60 MiB   5.9 GiB  1.07                   
MIN/MAX VAR: 0.83/1.28  STDDEV: 0.20
```

Check that the PDBs are correctly set:
```
$ kubectl get pdb -n rook-ceph
NAME            MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd   N/A             1                 1                     106s
```

Then, cordon a node and delete a OSD pod on the node to emulate draining the node:

```
$ kubectl cordon minikube-m02
node/minikube-m02 cordoned

$ kubectl delete pod -n rook-ceph rook-ceph-osd-1-dfb8dfc98-chmbj
pod "rook-ceph-osd-1-dfb8dfc98-chmbj" deleted
```

Check the result:
```
$ kubectl logs -n rook-ceph rook-ceph-operator-6644798f58-bj8t4 -f
2024-02-02 01:02:57.355897 I | clusterdisruption-controller: osd "rook-ceph-osd-1" is down and a possible node drain is detected
2024-02-02 01:02:57.788077 I | clusterdisruption-controller: osd is down in failure domain "minikube-m02". pg health: "cluster is not fully clean. PGs: [{StateName:active+clean Count:57} {StateName:active+undersized Count:22} {StateName:active+undersized+degraded Count:10}]"
2024-02-02 01:02:59.094658 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube" with maxUnavailable=0 for "host" failure domain "minikube"
2024-02-02 01:02:59.102011 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube-m03" with maxUnavailable=0 for "host" failure domain "minikube-m03"
2024-02-02 01:02:59.107224 I | clusterdisruption-controller: deleting the default pdb "rook-ceph-osd" with maxUnavailable=1 for all osd

$ kubectl get pdb -n rook-ceph ### <------------ The PDBs are correctly set
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd-host-minikube       N/A             0                 0                     2m14s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     2m14s

$ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE   RAW USE  DATA      OMAP  META     AVAIL     %USE  VAR   PGS  STATUS
 4    ssd  0.00099   1.00000  1 GiB  9.4 MiB   948 KiB   0 B  8.4 MiB  1015 MiB  0.92  0.79   46      up
 5    ssd  0.00099   1.00000  1 GiB   10 MiB   1.3 MiB   0 B  8.7 MiB  1014 MiB  0.98  0.85   43      up
 1    ssd  0.00099   1.00000  1 GiB   14 MiB   1.3 MiB   0 B   13 MiB  1010 MiB  1.37  1.19    0    down
 3    ssd  0.00099   1.00000  1 GiB   14 MiB   984 KiB   0 B   13 MiB  1010 MiB  1.33  1.15   57      up
 0    ssd  0.00099   1.00000  1 GiB   14 MiB  1012 KiB   0 B   13 MiB  1010 MiB  1.40  1.21   50      up
 2    ssd  0.00099   1.00000  1 GiB  9.5 MiB   1.3 MiB   0 B  8.2 MiB  1014 MiB  0.93  0.81   39      up
                       TOTAL  6 GiB   71 MiB   6.8 MiB   0 B   64 MiB   5.9 GiB  1.15                   
MIN/MAX VAR: 0.79/1.21  STDDEV: 0.21
```

Uncordon the node to reset:
```
$ kubectl uncordon minikube-m02

$ kubectl get pdb -n rook-ceph
NAME            MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd   N/A             1                 1                     5s
```

Next, we'll make an OSD that has no PGs. Set the OSD CRUSH weight of the OSD 2 to 0:
```
$ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd crush reweight osd.1 0
reweighted item id 1 name 'osd.1' to 0 in crush map

$ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE   RAW USE  DATA     OMAP     META     AVAIL     %USE  VAR   PGS  STATUS
 4    ssd  0.00099   1.00000  1 GiB  9.7 MiB  1.0 MiB      0 B  8.7 MiB  1014 MiB  0.95  0.88   49      up
 5    ssd  0.00099   1.00000  1 GiB   10 MiB  1.4 MiB      0 B  8.9 MiB  1014 MiB  1.01  0.93   40      up
 1    ssd        0   1.00000  1 GiB  6.7 MiB  956 KiB    1 KiB  5.7 MiB  1017 MiB  0.65  0.60    0      up
 3    ssd  0.00099   1.00000  1 GiB   15 MiB  1.6 MiB      0 B   13 MiB  1009 MiB  1.45  1.34   89      up
 0    ssd  0.00099   1.00000  1 GiB   15 MiB  1.1 MiB      0 B   14 MiB  1009 MiB  1.44  1.33   44      up
 2    ssd  0.00099   1.00000  1 GiB   10 MiB  1.4 MiB      0 B  8.6 MiB  1014 MiB  0.98  0.91   45      up
                       TOTAL  6 GiB   66 MiB  7.5 MiB  1.7 KiB   59 MiB   5.9 GiB  1.08                   
MIN/MAX VAR: 0.60/1.34  STDDEV: 0.28
```

Cordon the node and delete the pod:
```
$ kubectl cordon minikube-m02
$ kubectl delete pod -n rook-ceph rook-ceph-osd-1-dfb8dfc98-84c79
```

Check the result:
```
$ kubectl -n rook-ceph logs rook-ceph-operator-6644798f58-bj8t4 -f
2024-02-02 01:08:24.144809 I | clusterdisruption-controller: osd "rook-ceph-osd-1" is down and a possible node drain is detected
2024-02-02 01:08:24.572444 I | clusterdisruption-controller: osd is down in failure domain "minikube-m02". pg health: "all PGs in cluster are clean"
2024-02-02 01:08:26.209189 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube" with maxUnavailable=0 for "host" failure domain "minikube"
2024-02-02 01:08:26.217016 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube-m03" with maxUnavailable=0 for "host" failure domain "minikube-m03"
2024-02-02 01:08:26.221089 I | clusterdisruption-controller: deleting the default pdb "rook-ceph-osd" with maxUnavailable=1 for all osd

$ kubectl get pdb -n rook-ceph ### <----------- The PDBs are correctly set.
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd-host-minikube       N/A             0                 0                     29s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     29s
```
