# rook-ceph-dev

## Expected execution environment

- Minikube is already installed and kvm2 driver is enabled.
- CPU: >= 16 cores
- RAM: >= 32 GiB
- Disk: >= 100 GiB free

## Steps

```
$ make minikube/start minikube/setup-lvm topolvm/deploy
$ make rook/deploy-cluster rook/deploy-ceph-object-store
```

```
❯ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE   RAW USE  DATA      OMAP    META     AVAIL    %USE  VAR   PGS  STATUS
 2    ssd  0.00099   1.00000  1 GiB   27 MiB   576 KiB   4 KiB   27 MiB  997 MiB  2.67  0.99   44      up
 5    ssd  0.00099   1.00000  1 GiB   28 MiB  1012 KiB   4 KiB   27 MiB  996 MiB  2.72  1.01   45      up
 3    ssd  0.00099   1.00000  1 GiB   28 MiB     1 MiB   4 KiB   27 MiB  996 MiB  2.72  1.01   54      up
 4    ssd  0.00099   1.00000  1 GiB   27 MiB   564 KiB   4 KiB   27 MiB  997 MiB  2.67  0.99   35      up
 0    ssd  0.00099   1.00000  1 GiB   28 MiB   1.0 MiB   4 KiB   27 MiB  996 MiB  2.72  1.01   38      up
 1    ssd  0.00099   1.00000  1 GiB   27 MiB   520 KiB   4 KiB   27 MiB  997 MiB  2.66  0.99   51      up
                       TOTAL  6 GiB  165 MiB   4.7 MiB  26 KiB  161 MiB  5.8 GiB  2.69                   
MIN/MAX VAR: 0.99/1.01  STDDEV: 0.03

❯ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.00595  root default                                    
-7         0.00198      host minikube                               
 2    ssd  0.00099          osd.2              up   1.00000  1.00000
 5    ssd  0.00099          osd.5              up   1.00000  1.00000
-5         0.00198      host minikube-m02                           
 3    ssd  0.00099          osd.3              up   1.00000  1.00000
 4    ssd  0.00099          osd.4              up   1.00000  1.00000
-3         0.00198      host minikube-m03                           
 0    ssd  0.00099          osd.0              up   1.00000  1.00000
 1    ssd  0.00099          osd.1              up   1.00000  1.00000
```

```
$ kubectl drain --ignore-daemonsets --delete-emptydir-data minikube-m03
```
