#!/bin/bash

[[ $# -ne 1 ]] && echo "Please provide VMNAME as argument" && exit 254

SSHKEY=`cat ~/.ssh/id_rsa.pub`
PUBLICIP=`ip address show dev bond0 |grep bond0 |grep -v bond0:0 |grep inet |awk -F" " '{ print $2}' |awk -F"/" '{print $1}'`
VMNAME=$1
IMAGEURL="http://${PUBLICIP}:8080/rhel-8.1-update-3-x86_64-kvm.qcow2"

cat <<EOT > $VMNAME.yaml
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  annotations:
    kubevirt.io/latest-observed-api-version: v1alpha3
    kubevirt.io/storage-observed-api-version: v1alpha3
    name.os.template.kubevirt.io/rhel8.1: Red Hat Enterprise Linux 8.1
  selfLink: /apis/kubevirt.io/v1alpha3/namespaces/openshift-cnv/virtualmachines/VMNAME
  resourceVersion: '100003'
  name: VMNAME
  generation: 2
  namespace: openshift-cnv
  labels:
    app: VMNAME
    flavor.template.kubevirt.io/medium: 'true'
    os.template.kubevirt.io/rhel8.1: 'true'
    vm.kubevirt.io/template: rhel8-server-medium-v0.7.0
    vm.kubevirt.io/template.namespace: openshift
    vm.kubevirt.io/template.revision: '1'
    vm.kubevirt.io/template.version: v0.9.1
    workload.template.kubevirt.io/server: 'true'
spec:
  dataVolumeTemplates:
    - apiVersion: cdi.kubevirt.io/v1alpha1
      kind: DataVolume
      metadata:
        creationTimestamp: null
        name: VMNAME-rootdisk
      spec:
        pvc:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 10Gi
          volumeMode: Filesystem
        source:
          http:
            url: 'IMAGEURL'
      status: {}
  running: true
  template:
    metadata:
      creationTimestamp: null
      labels:
        flavor.template.kubevirt.io/medium: 'true'
        kubevirt.io/domain: VMNAME
        kubevirt.io/size: medium
        os.template.kubevirt.io/rhel8.1: 'true'
        vm.kubevirt.io/name: VMNAME
        workload.template.kubevirt.io/server: 'true'
    spec:
      domain:
        cpu:
          cores: 1
          sockets: 1
          threads: 1
        devices:
          disks:
            - bootOrder: 1
              disk:
                bus: virtio
              name: rootdisk
            - disk:
                bus: virtio
              name: cloudinitdisk
          interfaces:
            - masquerade: {}
              model: virtio
              name: nic0
          networkInterfaceMultiqueue: true
          rng: {}
        machine:
          type: pc-q35-rhel8.1.0
        resources:
          requests:
            memory: 4Gi
      evictionStrategy: LiveMigrate
      hostname: VMNAME
      networks:
        - name: nic0
          pod: {}
      terminationGracePeriodSeconds: 0
      volumes:
        - dataVolume:
            name: VMNAME-rootdisk
          name: rootdisk
        - cloudInitNoCloud:
            userData: |
              #cloud-config
              name: default
              ssh_authorized_keys:
                - >-
                  SSHKEY 
          name: cloudinitdisk
status: {}
EOT

sed -i "s%SSHKEY%${SSHKEY}%" $VMNAME.yaml
sed -i "s%VMNAME%${VMNAME}%g" $VMNAME.yaml


./oc create -f $VMNAME.yaml

