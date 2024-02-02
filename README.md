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
 1    ssd        0   1.00000  1 GiB  6.7 MiB  956 KiB    1 KiB  5.7 MiB  1017 MiB  0.65  0.60    0      up # <--------------- PGS == 0
 3    ssd  0.00099   1.00000  1 GiB   15 MiB  1.6 MiB      0 B   13 MiB  1009 MiB  1.45  1.34   89      up
 0    ssd  0.00099   1.00000  1 GiB   15 MiB  1.1 MiB      0 B   14 MiB  1009 MiB  1.44  1.33   44      up
 2    ssd  0.00099   1.00000  1 GiB   10 MiB  1.4 MiB      0 B  8.6 MiB  1014 MiB  0.98  0.91   45      up
                       TOTAL  6 GiB   66 MiB  7.5 MiB  1.7 KiB   59 MiB   5.9 GiB  1.08                   
MIN/MAX VAR: 0.60/1.34  STDDEV: 0.28
```

Cordon the node and delete the pod:
```
$ kubectl cordon minikube-m02
$ kubectl delete pod -n rook-ceph rook-ceph-osd-1-dfb8dfc98-xxsp4
```

Check the result:
```
$ kubectl -n rook-ceph logs rook-ceph-operator-6644798f58-bj8t4 -f
2024-02-02 01:11:20.170147 I | clusterdisruption-controller: osd "rook-ceph-osd-1" is down and a possible node drain is detected
2024-02-02 01:11:20.615101 I | clusterdisruption-controller: osd is down in failure domain "minikube-m02". pg health: "all PGs in cluster are clean"
2024-02-02 01:11:22.284086 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube" with maxUnavailable=0 for "host" failure domain "minikube"
2024-02-02 01:11:22.292043 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube-m03" with maxUnavailable=0 for "host" failure domain "minikube-m03"
2024-02-02 01:11:22.296280 I | clusterdisruption-controller: deleting the default pdb "rook-ceph-osd" with maxUnavailable=1 for all osd

$ kubectl get pdb -n rook-ceph ### <----------- The PDBs are correctly set.
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd-host-minikube       N/A             0                 0                     29s
rook-ceph-osd-host-minikube-m03   N/A             0                 0                     29s
```

## Additional Investigation

### Case 2: when an OSD deployment is removed

The result: the blocking PDBs are correctly set.

```
$ kubectl get pdb -n rook-ceph
NAME            MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd   N/A             1                 1                     4m41s

$ kubectl get deploy -n rook-ceph
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
csi-cephfsplugin-provisioner   2/2     2            2           16m
csi-rbdplugin-provisioner      2/2     2            2           16m
rook-ceph-mgr-a                1/1     1            1           15m
rook-ceph-mon-a                1/1     1            1           16m
rook-ceph-operator             1/1     1            1           17m
rook-ceph-osd-0                1/1     1            1           15m
rook-ceph-osd-1                1/1     1            1           15m
rook-ceph-osd-2                1/1     1            1           14m
rook-ceph-osd-3                1/1     1            1           14m
rook-ceph-osd-4                1/1     1            1           14m
rook-ceph-osd-5                1/1     1            1           14m
rook-ceph-rgw-my-store-a       1/1     1            1           4m44s
rook-ceph-tools                1/1     1            1           17m

$ kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.00595  root default                                    
-7         0.00198      host minikube                               
 4    ssd  0.00099          osd.4              up   1.00000  1.00000
 5    ssd  0.00099          osd.5              up   1.00000  1.00000
-5         0.00198      host minikube-m02                           
 2    ssd  0.00099          osd.2              up   1.00000  1.00000
 3    ssd  0.00099          osd.3              up   1.00000  1.00000
-3         0.00198      host minikube-m03                           
 0    ssd  0.00099          osd.0              up   1.00000  1.00000
 1    ssd  0.00099          osd.1              up   1.00000  1.00000

$ kubectl delete deploy -n rook-ceph rook-ceph-osd-0
deployment.apps "rook-ceph-osd-0" deleted

$ kubectl get pdb -n rook-ceph # <------- The blocking PDBs are correctly set.
NAME                              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd-host-minikube       N/A             0                 0                     26s
rook-ceph-osd-host-minikube-m02   N/A             0                 0                     26s

$ kubectl -n rook-ceph logs rook-ceph-operator-6644798f58-bj8t4 -f
2024-02-02 06:03:22.690348 I | ceph-spec: object "rook-ceph-osd-0" matched on delete, reconciling
2024-02-02 06:03:22.690647 I | ceph-cluster-controller: reconciling ceph cluster in namespace "rook-ceph"
2024-02-02 06:03:22.696347 I | ceph-spec: parsing mon endpoints: a=10.108.33.206:6789
2024-02-02 06:03:22.727722 I | ceph-spec: detecting the ceph image version for image quay.io/ceph/ceph:v17.2.6...
2024-02-02 06:03:23.171960 I | clusterdisruption-controller: reconciling osd pdb reconciler as the allowed disruptions in default pdb is 0
2024-02-02 06:03:25.011584 I | ceph-spec: detected ceph image version: "17.2.6-0 quincy"
2024-02-02 06:03:25.011608 I | ceph-cluster-controller: validating ceph version from provided image
2024-02-02 06:03:25.023051 I | ceph-spec: parsing mon endpoints: a=10.108.33.206:6789
2024-02-02 06:03:25.027704 I | cephclient: writing config file /var/lib/rook/rook-ceph/rook-ceph.config
2024-02-02 06:03:25.027903 I | cephclient: generated admin config in /var/lib/rook/rook-ceph
2024-02-02 06:03:25.482755 I | ceph-cluster-controller: cluster "rook-ceph": version "17.2.6-0 quincy" detected for image "quay.io/ceph/ceph:v17.2.6"
2024-02-02 06:03:25.527562 I | op-mon: start running mons
2024-02-02 06:03:25.532332 I | ceph-spec: parsing mon endpoints: a=10.108.33.206:6789
2024-02-02 06:03:26.400310 I | op-mon: saved mon endpoints to config map map[csi-cluster-config-json:[{"clusterID":"rook-ceph","monitors":["10.108.33.206:6789"],"namespace":""}] data:a=10.108.33.206:6789 mapping:{"node":{"a":null}} maxMonId:0 outOfQuorum:]
2024-02-02 06:03:26.999410 I | cephclient: writing config file /var/lib/rook/rook-ceph/rook-ceph.config
2024-02-02 06:03:27.000061 I | cephclient: generated admin config in /var/lib/rook/rook-ceph
2024-02-02 06:03:28.600094 I | op-mon: targeting the mon count 1
2024-02-02 06:03:28.608406 I | op-config: applying ceph settings:
[global]
mon allow pool delete   = true
mon cluster log file    = 
mon allow pool size one = true
2024-02-02 06:03:28.959593 I | op-config: successfully applied settings to the mon configuration database
2024-02-02 06:03:28.960312 I | op-config: applying ceph settings:
[global]
log to file = false
2024-02-02 06:03:29.320878 I | op-config: successfully applied settings to the mon configuration database
2024-02-02 06:03:29.320959 I | op-config: deleting "log file" option from the mon configuration database
2024-02-02 06:03:29.667176 I | op-config: successfully deleted "log file" option from the mon configuration database
2024-02-02 06:03:29.667205 I | op-mon: checking for basic quorum with existing mons
2024-02-02 06:03:29.694640 I | op-mon: mon "a" cluster IP is 10.108.33.206
2024-02-02 06:03:30.001931 I | op-mon: saved mon endpoints to config map map[csi-cluster-config-json:[{"clusterID":"rook-ceph","monitors":["10.108.33.206:6789"],"namespace":""}] data:a=10.108.33.206:6789 mapping:{"node":{"a":null}} maxMonId:0 outOfQuorum:]
2024-02-02 06:03:30.598578 I | cephclient: writing config file /var/lib/rook/rook-ceph/rook-ceph.config
2024-02-02 06:03:30.598833 I | cephclient: generated admin config in /var/lib/rook/rook-ceph
2024-02-02 06:03:31.200081 I | op-mon: deployment for mon rook-ceph-mon-a already exists. updating if needed
2024-02-02 06:03:31.208894 I | op-k8sutil: deployment "rook-ceph-mon-a" did not change, nothing to update
2024-02-02 06:03:31.208913 I | op-mon: waiting for mon quorum with [a]
2024-02-02 06:03:31.404094 I | op-mon: mons running: [a]
2024-02-02 06:03:31.837828 I | op-mon: Monitors in quorum: [a]
2024-02-02 06:03:31.837850 I | op-mon: mons created: 1
2024-02-02 06:03:32.270123 I | op-mon: waiting for mon quorum with [a]
2024-02-02 06:03:32.279493 I | op-mon: mons running: [a]
2024-02-02 06:03:32.723719 I | op-mon: Monitors in quorum: [a]
2024-02-02 06:03:32.723750 I | ceph-spec: not applying network settings for cluster "rook-ceph" ceph networks
2024-02-02 06:03:32.723756 I | op-mon: checking for orphaned mon resources
2024-02-02 06:03:32.731803 I | cephclient: getting or creating ceph auth key "client.csi-rbd-provisioner"
2024-02-02 06:03:33.172674 I | cephclient: getting or creating ceph auth key "client.csi-rbd-node"
2024-02-02 06:03:33.609822 I | cephclient: getting or creating ceph auth key "client.csi-cephfs-provisioner"
2024-02-02 06:03:34.038310 I | cephclient: getting or creating ceph auth key "client.csi-cephfs-node"
2024-02-02 06:03:34.512622 I | ceph-csi: created kubernetes csi secrets for cluster "rook-ceph"
2024-02-02 06:03:34.512647 I | cephclient: getting or creating ceph auth key "client.crash"
2024-02-02 06:03:34.956443 I | ceph-nodedaemon-controller: created kubernetes crash collector secret for cluster "rook-ceph"
2024-02-02 06:03:34.956472 I | cephclient: getting or creating ceph auth key "client.ceph-exporter"
2024-02-02 06:03:35.413389 I | ceph-nodedaemon-controller: created kubernetes exporter secret for cluster "rook-ceph"
2024-02-02 06:03:35.413421 I | op-config: deleting "ms_cluster_mode" option from the mon configuration database
2024-02-02 06:03:35.778896 I | op-config: successfully deleted "ms_cluster_mode" option from the mon configuration database
2024-02-02 06:03:35.778926 I | op-config: deleting "ms_service_mode" option from the mon configuration database
2024-02-02 06:03:36.133121 I | op-config: successfully deleted "ms_service_mode" option from the mon configuration database
2024-02-02 06:03:36.133151 I | op-config: deleting "ms_client_mode" option from the mon configuration database
2024-02-02 06:03:36.543382 I | op-config: successfully deleted "ms_client_mode" option from the mon configuration database
2024-02-02 06:03:36.543410 I | op-config: deleting "rbd_default_map_options" option from the mon configuration database
2024-02-02 06:03:36.888176 I | op-config: successfully deleted "rbd_default_map_options" option from the mon configuration database
2024-02-02 06:03:36.888366 I | op-config: deleting "ms_osd_compress_mode" option from the mon configuration database
2024-02-02 06:03:37.247011 I | op-config: successfully deleted "ms_osd_compress_mode" option from the mon configuration database
2024-02-02 06:03:37.247087 I | cephclient: create rbd-mirror bootstrap peer token "client.rbd-mirror-peer"
2024-02-02 06:03:37.247098 I | cephclient: getting or creating ceph auth key "client.rbd-mirror-peer"
2024-02-02 06:03:37.695612 I | cephclient: successfully created rbd-mirror bootstrap peer token for cluster "rook-ceph"
2024-02-02 06:03:37.717973 I | op-mgr: start running mgr
2024-02-02 06:03:37.722042 I | cephclient: getting or creating ceph auth key "mgr.a"
2024-02-02 06:03:38.335909 I | op-mgr: deployment for mgr rook-ceph-mgr-a already exists. updating if needed
2024-02-02 06:03:38.344193 I | op-k8sutil: deployment "rook-ceph-mgr-a" did not change, nothing to update
2024-02-02 06:03:38.376455 I | op-mgr: successful modules: mgr module(s) from the spec
2024-02-02 06:03:38.376637 I | op-mgr: successful modules: balancer
2024-02-02 06:03:38.388125 I | op-osd: start running osds in namespace "rook-ceph"
2024-02-02 06:03:38.388189 I | op-osd: wait timeout for healthy OSDs during upgrade or restart is "10m0s"
2024-02-02 06:03:38.402050 I | op-osd: start provisioning the OSDs on PVCs, if needed
2024-02-02 06:03:38.406715 I | op-osd: verifying PVCs exist for 6 OSDs in device set "set1"
2024-02-02 06:03:38.406774 I | op-osd: OSD PVC "set1-data-5tnhs4" already exists
2024-02-02 06:03:38.406789 I | op-osd: OSD PVC "set1-data-0jhxwl" already exists
2024-02-02 06:03:38.407792 I | op-osd: OSD PVC "set1-data-1z7fkr" already exists
2024-02-02 06:03:38.407837 I | op-osd: OSD PVC "set1-data-2zm5c2" already exists
2024-02-02 06:03:38.407913 I | op-osd: OSD PVC "set1-data-3xp2pv" already exists
2024-02-02 06:03:38.407973 I | op-osd: OSD PVC "set1-data-4jzjqp" already exists
2024-02-02 06:03:38.419991 I | op-osd: OSD will have its main bluestore block on "set1-data-5tnhs4"
2024-02-02 06:03:38.420020 I | op-osd: skipping OSD prepare job creation for PVC "set1-data-5tnhs4" because OSD daemon using the PVC already exists
2024-02-02 06:03:38.420024 I | op-osd: OSD will have its main bluestore block on "set1-data-0jhxwl"
2024-02-02 06:03:38.528659 I | op-k8sutil: Removing previous job rook-ceph-osd-prepare-set1-data-0jhxwl to start a new one
2024-02-02 06:03:38.538155 I | op-k8sutil: batch job rook-ceph-osd-prepare-set1-data-0jhxwl still exists
2024-02-02 06:03:39.498332 I | op-mgr: successful modules: prometheus
2024-02-02 06:03:39.499198 I | op-mgr: successful modules: dashboard
2024-02-02 06:03:41.542459 I | op-k8sutil: batch job rook-ceph-osd-prepare-set1-data-0jhxwl deleted
2024-02-02 06:03:41.551749 I | op-osd: started OSD provisioning job for PVC "set1-data-0jhxwl"
2024-02-02 06:03:41.551819 I | op-osd: OSD will have its main bluestore block on "set1-data-1z7fkr"
2024-02-02 06:03:41.551832 I | op-osd: skipping OSD prepare job creation for PVC "set1-data-1z7fkr" because OSD daemon using the PVC already exists
2024-02-02 06:03:41.551844 I | op-osd: OSD will have its main bluestore block on "set1-data-2zm5c2"
2024-02-02 06:03:41.551853 I | op-osd: skipping OSD prepare job creation for PVC "set1-data-2zm5c2" because OSD daemon using the PVC already exists
2024-02-02 06:03:41.551863 I | op-osd: OSD will have its main bluestore block on "set1-data-3xp2pv"
2024-02-02 06:03:41.551872 I | op-osd: skipping OSD prepare job creation for PVC "set1-data-3xp2pv" because OSD daemon using the PVC already exists
2024-02-02 06:03:41.551883 I | op-osd: OSD will have its main bluestore block on "set1-data-4jzjqp"
2024-02-02 06:03:41.551892 I | op-osd: skipping OSD prepare job creation for PVC "set1-data-4jzjqp" because OSD daemon using the PVC already exists
2024-02-02 06:03:41.551903 I | op-osd: start provisioning the OSDs on nodes, if needed
2024-02-02 06:03:41.551911 I | op-osd: no nodes are defined for configuring OSDs on raw devices
2024-02-02 06:03:41.555043 I | op-osd: OSD orchestration status for PVC set1-data-0jhxwl is "starting"
2024-02-02 06:03:43.149129 I | op-osd: updating OSD 1 on PVC "set1-data-3xp2pv"
2024-02-02 06:03:43.149190 I | op-osd: OSD will have its main bluestore block on "set1-data-3xp2pv"
2024-02-02 06:03:44.734064 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:44.734116 I | op-osd: OSD orchestration status for node set1-data-0jhxwl is "orchestrating"
2024-02-02 06:03:46.260876 I | op-osd: OSD 3 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:46.260940 I | op-osd: OSD orchestration status for PVC set1-data-0jhxwl is "orchestrating"
2024-02-02 06:03:46.261158 I | op-osd: OSD orchestration status for PVC set1-data-0jhxwl is "completed"
2024-02-02 06:03:46.261176 I | op-osd: creating OSD 0 on PVC "set1-data-0jhxwl"
2024-02-02 06:03:46.261182 I | op-osd: OSD will have its main bluestore block on "set1-data-0jhxwl"
2024-02-02 06:03:46.331830 I | clusterdisruption-controller: osd "rook-ceph-osd-0" is down and a possible node drain is detected
2024-02-02 06:03:46.800409 I | clusterdisruption-controller: osd is down in failure domain "minikube-m03". pg health: "cluster is not fully clean. PGs: [{StateName:active+clean Count:52} {StateName:active+undersized Count:28} {StateName:active+undersized+degraded Count:14} {StateName:active+clean+remapped Count:1}]"
2024-02-02 06:03:48.029866 I | op-osd: OSD 4 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:48.518636 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube" with maxUnavailable=0 for "host" failure domain "minikube"
2024-02-02 06:03:48.525017 I | clusterdisruption-controller: creating temporary blocking pdb "rook-ceph-osd-host-minikube-m02" with maxUnavailable=0 for "host" failure domain "minikube-m02"
2024-02-02 06:03:48.529154 I | clusterdisruption-controller: deleting the default pdb "rook-ceph-osd" with maxUnavailable=1 for all osd
2024-02-02 06:03:49.686675 I | op-osd: OSD 5 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:51.267731 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:52.782449 I | op-osd: OSD 3 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:53.173706 I | clusterdisruption-controller: osd "rook-ceph-osd-0" is down but no node drain is detected
2024-02-02 06:03:53.633039 I | clusterdisruption-controller: osd is down in failure domain "minikube-m03". pg health: "cluster is not fully clean. PGs: [{StateName:active+clean Count:52} {StateName:active+undersized Count:28} {StateName:active+undersized+degraded Count:14} {StateName:active+clean+remapped Count:1}]"
2024-02-02 06:03:54.341409 I | op-osd: OSD 4 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:55.883346 I | op-osd: OSD 5 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:57.491268 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2024-02-02 06:03:59.008051 I | op-osd: OSD 3 is not ok-to-stop. will try updating it again later
2024-02-02 06:04:00.575395 I | op-osd: updating OSD 4 on PVC "set1-data-1z7fkr"
2024-02-02 06:04:00.575431 I | op-osd: OSD will have its main bluestore block on "set1-data-1z7fkr"
2024-02-02 06:04:02.535214 I | op-osd: updating OSD 5 on PVC "set1-data-4jzjqp"
2024-02-02 06:04:02.535241 I | op-osd: OSD will have its main bluestore block on "set1-data-4jzjqp"
2024-02-02 06:04:04.175859 I | op-osd: updating OSD 2 on PVC "set1-data-2zm5c2"
2024-02-02 06:04:04.175888 I | op-osd: OSD will have its main bluestore block on "set1-data-2zm5c2"
2024-02-02 06:04:04.199186 I | op-osd: updating OSD 3 on PVC "set1-data-5tnhs4"
2024-02-02 06:04:04.199213 I | op-osd: OSD will have its main bluestore block on "set1-data-5tnhs4"
2024-02-02 06:04:05.097905 I | cephclient: successfully disallowed pre-quincy osds and enabled all new quincy-only functionality
2024-02-02 06:04:05.500235 I | op-osd: finished running OSDs in namespace "rook-ceph"
2024-02-02 06:04:05.500271 I | ceph-cluster-controller: done reconciling ceph cluster in namespace "rook-ceph"
2024-02-02 06:04:05.512821 I | ceph-cluster-controller: reporting cluster telemetry
2024-02-02 06:04:11.915698 I | ceph-cluster-controller: reporting node telemetry
2024-02-02 06:04:24.451042 I | clusterdisruption-controller: all "host" failure domains: [minikube minikube-m02 minikube-m03]. osd is down in failure domain: "". active node drains: false. pg health: "cluster is not fully clean. PGs: [{StateName:active+clean Count:88} {StateName:clean+premerge+peered Count:1}]"
2024-02-02 06:04:56.306078 I | clusterdisruption-controller: all PGs are active+clean. Restoring default OSD pdb settings
2024-02-02 06:04:56.306107 I | clusterdisruption-controller: creating the default pdb "rook-ceph-osd" with maxUnavailable=1 for all osd
2024-02-02 06:04:56.313565 I | clusterdisruption-controller: deleting temporary blocking pdb with "rook-ceph-osd-host-minikube" with maxUnavailable=0 for "host" failure domain "minikube"
2024-02-02 06:04:56.319120 I | clusterdisruption-controller: deleting temporary blocking pdb with "rook-ceph-osd-host-minikube-m02" with maxUnavailable=0 for "host" failure domain "minikube-m02"

$ kubectl get pdb -n rook-ceph <------ The PDBs are reset after the deployment is ready.
NAME            MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
rook-ceph-osd   N/A             1                 1                     18s

$ kubectl get deploy -n rook-ceph
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
csi-cephfsplugin-provisioner   2/2     2            2           18m
csi-rbdplugin-provisioner      2/2     2            2           18m
rook-ceph-mgr-a                1/1     1            1           17m
rook-ceph-mon-a                1/1     1            1           18m
rook-ceph-operator             1/1     1            1           19m
rook-ceph-osd-0                1/1     1            1           100s
rook-ceph-osd-1                1/1     1            1           17m
rook-ceph-osd-2                1/1     1            1           16m
rook-ceph-osd-3                1/1     1            1           16m
rook-ceph-osd-4                1/1     1            1           16m
rook-ceph-osd-5                1/1     1            1           16m
rook-ceph-rgw-my-store-a       1/1     1            1           7m
rook-ceph-tools                1/1     1            1           19m
```
