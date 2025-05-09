# rook-ceph-dev

## Usage

Deploy Minikube, TopoLVM, Rook, and RGW.

```
$ git clone https://github.com/ushitora-anqou/rook-on-minikube.git
$ cd rook-on-minikube
$ git checkout pdbs-remain
$ git submodule update --init --recursive
$ make minikube/start
$ make minikube/setup-lvm
$ make topolvm/deploy
$ make -C rook build
$ make rook/load-dev-image IMAGE=build-dd170aa7/ceph-amd64
$ make rook/deploy-cluster
$ make rook/deploy-ceph-object-store
```

After the setup:

```
❯ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE   RAW USE  DATA     OMAP     META     AVAIL    %USE  VAR   PGS  STATUS
 0    ssd  0.00099   1.00000  1 GiB   27 MiB  612 KiB    1 KiB   26 MiB  997 MiB  2.64  0.97   41      up
 1    ssd  0.00099   1.00000  1 GiB   31 MiB  604 KiB    1 KiB   30 MiB  993 MiB  3.03  1.11   36      up
 5    ssd  0.00099   1.00000  1 GiB   27 MiB  1.1 MiB    1 KiB   26 MiB  997 MiB  2.68  0.99   66      up
 4    ssd  0.00099   1.00000  1 GiB   27 MiB  1.1 MiB    1 KiB   26 MiB  997 MiB  2.68  0.98   46      up
 2    ssd  0.00099   1.00000  1 GiB   27 MiB  1.0 MiB    1 KiB   26 MiB  997 MiB  2.67  0.98   41      up
 3    ssd  0.00099   1.00000  1 GiB   27 MiB  628 KiB    1 KiB   26 MiB  997 MiB  2.64  0.97   37      up
                       TOTAL  6 GiB  167 MiB  5.0 MiB  9.5 KiB  162 MiB  5.8 GiB  2.72                   
MIN/MAX VAR: 0.97/1.11  STDDEV: 0.14

❯ kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.00595  root default                                    
-3         0.00198      host minikube                               
 0    ssd  0.00099          osd.0              up   1.00000  1.00000
 1    ssd  0.00099          osd.1              up   1.00000  1.00000
-9         0.00099      host minikube-m02                           
 5    ssd  0.00099          osd.5              up   1.00000  1.00000
-7         0.00099      host minikube-m03                           
 4    ssd  0.00099          osd.4              up   1.00000  1.00000
-5         0.00198      host minikube-m04                           
 2    ssd  0.00099          osd.2              up   1.00000  1.00000
 3    ssd  0.00099          osd.3              up   1.00000  1.00000

❯ kubectl get node
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   31m   v1.28.3
minikube-m02   Ready    <none>          30m   v1.28.3
minikube-m03   Ready    <none>          29m   v1.28.3
minikube-m04   Ready    <none>          29m   v1.28.3
```

First, we drain a node:

```
❯ kubectl drain --ignore-daemonsets --delete-emptydir-data minikube-m02
```

Rook creates blocking PDBs as expected:

```
❯ kubectl get pdb -n rook-ceph
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd-host-minikube       N/A             0                 0                     24s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     24s
rook-ceph-osd-host-minikube-m04   N/A             0                 0                     24s
```

Next, we emulate a node failure by `minikube node stop`:

```
❯ minikube node list
minikube        192.168.39.111
minikube-m02    192.168.39.184
minikube-m03    192.168.39.107
minikube-m04    192.168.39.223

❯ minikube node stop minikube-m04
✋  Stopping node "minikube-m04"  ...
🛑  Successfully stopped node minikube-m04

❯ kubectl get node
NAME           STATUS                     ROLES           AGE     VERSION
minikube       Ready                      control-plane   39m     v1.28.3
minikube-m02   Ready,SchedulingDisabled   <none>          39m     v1.28.3
minikube-m03   Ready                      <none>          38m     v1.28.3
minikube-m04   NotReady                   <none>          2m55s   v1.28.3
```

After that, we uncordon `minikube-m02` and bring it back:

```
❯ kubectl uncordon minikube-m02
node/minikube-m02 uncordoned

❯ kubectl get node
NAME           STATUS     ROLES           AGE     VERSION
minikube       Ready      control-plane   40m     v1.28.3
minikube-m02   Ready      <none>          39m     v1.28.3
minikube-m03   Ready      <none>          39m     v1.28.3
minikube-m04   NotReady   <none>          3m33s   v1.28.3
```

Here, we have only one broken node, i.e., `minikube-m04`. So, the blocking PDBs should be re-created for it. However, Rook seems to stick to the old PDBs:

```
❯ kubectl get pdb -n rook-ceph
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd-host-minikube       N/A             0                 0                     9m18s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     9m18s
rook-ceph-osd-host-minikube-m04   N/A             0                 0                     9m18s
```

Logs from the Rook operator:

```
2025-05-09 00:52:54.899634 I | clusterdisruption-controller: osd "rook-ceph-osd-3" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:52:54.899877 I | clusterdisruption-controller: osd "rook-ceph-osd-2" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:52:55.364187 I | clusterdisruption-controller: OSD(s) [3 2] are down and PGs are not clean. PGs Status: "cluster is not fully clean. PGs: [{StateName:active+undersized Count:57} {StateName:active+undersized+degraded Count:21} {StateName:active+clean Count:11}]"
2025-05-09 00:52:55.364214 I | clusterdisruption-controller: OSD failure Domains : ["minikube" "minikube-m02" "minikube-m03" "minikube-m04"]
2025-05-09 00:52:55.364218 I | clusterdisruption-controller: Draining Failure Domain: "minikube-m02"
2025-05-09 00:52:55.364221 I | clusterdisruption-controller: Set noout on draining Failure Domain: "true"
2025-05-09 00:52:55.738477 I | clusterdisruption-controller: reconciling osd pdb controller
2025-05-09 00:53:04.255709 I | clusterdisruption-controller: osd "rook-ceph-osd-3" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:53:04.255758 I | clusterdisruption-controller: osd "rook-ceph-osd-2" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:53:04.740154 I | clusterdisruption-controller: OSD(s) [3 2] are down and PGs are not clean. PGs Status: "cluster is not fully clean. PGs: [{StateName:active+undersized Count:57} {StateName:active+undersized+degraded Count:21} {StateName:active+clean Count:11}]"
2025-05-09 00:53:04.740194 I | clusterdisruption-controller: OSD failure Domains : ["minikube" "minikube-m02" "minikube-m03" "minikube-m04"]
2025-05-09 00:53:04.740198 I | clusterdisruption-controller: Draining Failure Domain: "minikube-m02"
2025-05-09 00:53:04.740201 I | clusterdisruption-controller: Set noout on draining Failure Domain: "true"
2025-05-09 00:53:05.135020 I | clusterdisruption-controller: reconciling osd pdb controller
2025-05-09 00:53:11.181996 I | clusterdisruption-controller: osd "rook-ceph-osd-2" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:53:11.182053 I | clusterdisruption-controller: osd "rook-ceph-osd-3" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:53:11.638576 I | clusterdisruption-controller: OSD(s) [2 3] are down and PGs are not clean. PGs Status: "cluster is not fully clean. PGs: [{StateName:active+undersized Count:57} {StateName:active+undersized+degraded Count:21} {StateName:active+clean Count:11}]"
2025-05-09 00:53:11.638611 I | clusterdisruption-controller: OSD failure Domains : ["minikube" "minikube-m02" "minikube-m03" "minikube-m04"]
2025-05-09 00:53:11.638615 I | clusterdisruption-controller: Draining Failure Domain: "minikube-m02"
2025-05-09 00:53:11.638618 I | clusterdisruption-controller: Set noout on draining Failure Domain: "true"
2025-05-09 00:53:12.100626 I | clusterdisruption-controller: reconciling osd pdb controller
2025-05-09 00:53:20.634697 I | clusterdisruption-controller: osd "rook-ceph-osd-2" is down on node "minikube-m04" but no node drain is detected
2025-05-09 00:53:20.634728 I | clusterdisruption-controller: osd "rook-ceph-osd-3" is down on node "minikube-m04" but no node drain is detected
```
