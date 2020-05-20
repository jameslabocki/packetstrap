#!/bin/bash

PUBLICIP=`ip address show dev bond0 |grep bond0 |grep -v bond0:0 |grep inet |awk -F" " '{ print $2}' |awk -F"/" '{print $1}'`


cat <<EOT > pv001.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv001
spec:
  capacity:
    storage: 12Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/data
    server: PUBLICIP
EOT

cat <<EOT > pv002.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv002
spec:
  capacity:
    storage: 12Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/data
    server: PUBLICIP
EOT

cat <<EOT > pv003.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv003
spec:
  capacity:
    storage: 12Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/data
    server: PUBLICIP
EOT

cat <<EOT > pv004.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv004
spec:
  capacity:
    storage: 12Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/data
    server: PUBLICIP
EOT

sed -i "s/PUBLICIP/$PUBLICIP/g" pv001.yaml 
sed -i "s/PUBLICIP/$PUBLICIP/g" pv002.yaml 
sed -i "s/PUBLICIP/$PUBLICIP/g" pv003.yaml 
sed -i "s/PUBLICIP/$PUBLICIP/g" pv004.yaml 

./oc create -f pv001.yaml
./oc create -f pv002.yaml
./oc create -f pv003.yaml
./oc create -f pv004.yaml

