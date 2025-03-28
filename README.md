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
$ git checkout rook-15341
$ git submodule update --init --recursive
$ make minikube/start
$ make minikube/setup-lvm
$ make topolvm/deploy
$ make -C rook build
$ make rook/load-dev-image IMAGE=build-dd170aa7/ceph-amd64
$ make rook/deploy-cluster
$ make rook/deploy-ceph-object-store
```

We'll make an OSD that has no PGs. Set the OSD CRUSH weight of the OSD 5 to 0:
```
$ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd crush reweight osd.5 0
reweighted item id 1 name 'osd.1' to 0 in crush map

$ kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE   RAW USE  DATA     OMAP     META     AVAIL    %USE  VAR   PGS  STATUS
 0    ssd  0.00099   1.00000  1 GiB   27 MiB  636 KiB    1 KiB   26 MiB  997 MiB  2.64  0.95   40      up
 1    ssd  0.00099   1.00000  1 GiB   27 MiB  1.1 MiB    1 KiB   26 MiB  997 MiB  2.68  0.96   49      up
 5    ssd        0   1.00000  1 GiB   31 MiB  528 KiB    1 KiB   30 MiB  993 MiB  3.02  1.08    0      up # <------ PGS == 0
 2    ssd  0.00099   1.00000  1 GiB   27 MiB  588 KiB    1 KiB   26 MiB  997 MiB  2.63  0.94   40      up
 3    ssd  0.00099   1.00000  1 GiB   32 MiB  1.1 MiB    1 KiB   30 MiB  992 MiB  3.08  1.10   49      up
 4    ssd  0.00099   1.00000  1 GiB   28 MiB  1.1 MiB    1 KiB   26 MiB  996 MiB  2.69  0.96   89      up
                       TOTAL  6 GiB  171 MiB  5.0 MiB  9.5 KiB  166 MiB  5.8 GiB  2.79                   
MIN/MAX VAR: 0.94/1.10  STDDEV: 0.19

$ kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.00496  root default                                    
-3         0.00198      host minikube                               
 0    ssd  0.00099          osd.0              up   1.00000  1.00000
 1    ssd  0.00099          osd.1              up   1.00000  1.00000
-9               0      host minikube-m02                           
 5    ssd        0          osd.5              up   1.00000  1.00000
-5         0.00198      host minikube-m03                           
 2    ssd  0.00099          osd.2              up   1.00000  1.00000
 3    ssd  0.00099          osd.3              up   1.00000  1.00000
-7         0.00099      host minikube-m04                           
 4    ssd  0.00099          osd.4              up   1.00000  1.00000
```

Drain the node:
```
$ kubectl drain --ignore-daemonsets --delete-emptydir-data minikube-m02
```

Check the result:
```
$ kubectl get pdb -n rook-ceph -w
NAME            MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd   N/A             1                 0                     3m11s
rook-ceph-osd   N/A             2                 0                     3m55s
rook-ceph-osd   N/A             2                 1                     3m55s
rook-ceph-osd   N/A             1                 1                     4m27s
rook-ceph-osd   N/A             1                 0                     4m27s
rook-ceph-osd   N/A             2                 0                     5m29s
rook-ceph-osd   N/A             2                 1                     5m29s
rook-ceph-osd   N/A             1                 1                     6m1s
rook-ceph-osd   N/A             1                 0                     6m1s
rook-ceph-osd   N/A             2                 0                     7m3s
rook-ceph-osd   N/A             2                 1                     7m3s
rook-ceph-osd   N/A             1                 1                     7m34s
rook-ceph-osd   N/A             1                 0                     7m34s
```
