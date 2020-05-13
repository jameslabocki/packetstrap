#!/bin/bash

# This simple bash scripts will
#  
#
# You need to:
#   - Pass your subscription pool ID as $1
#   - have your pull secret in a file named pull-secret.txt in the same directory as this script


echo "==== Setting variables"
POOL=$1
BASEDOMAIN=$2
METADATANAME=$3
PULLSECRET=`cat pull-secret.txt`
SSHKEY=`cat ~/.ssh/id_rsa.pub`
PUBLICIP=`ip address show dev bond0 |grep bond0 |grep -v bond0:0 |grep inet |awk -F" " '{ print $2}' |awk -F"/" '{print $1}'`


# Register
echo "==== registering with subscription manager"
subscription-manager register
subscription-manager attach --pool=${POOL}

echo "==== clean up yum and repo setup"
yum clean all
yum install yum-utils -y
yum-config-manager --add-repo rhel-7-server-rpms
yum-config-manager --add-repo rhel-7-server-extra-rpms

echo "==== setup firewall"
firewall-cmd --add-port=80/tcp
firewall-cmd --add-port=443/tcp
firewall-cmd --add-port=8080/tcp
firewall-cmd --add-port=8088/tcp
firewall-cmd --add-port=6443/tcp
firewall-cmd --add-port=22623/tcp
firewall-cmd --add-port=2376/tcp
firewall-cmd --add-port=2376/udp
firewall-cmd --add-port=111/tcp
firewall-cmd --add-port=662/tcp
firewall-cmd --add-port=875/tcp
firewall-cmd --add-port=892/tcp
firewall-cmd --add-port=2049/tcp
firewall-cmd --add-port=32803/tcp
firewall-cmd --add-port=111/udp
firewall-cmd --add-port=662/udp
firewall-cmd --add-port=875/udp
firewall-cmd --add-port=892/udp
firewall-cmd --add-port=2049/udp
firewall-cmd --add-port=32803/udp
firewall-cmd --runtime-to-permanent

echo "==== install and configure nfs"
yum install nfs-utils -y
echo "/mnt/data *(rw,root_squash)" >> /etc/exports
mkdir /mnt/data
service nfs start
exportfs

echo "==== install and configure haproxy"
yum install haproxy -y
cat <<EOT > /etc/haproxy/haproxy.cfg
defaults
	mode                	http
	log                 	global
	option              	httplog
	option              	dontlognull
	option forwardfor   	except 127.0.0.0/8
	option              	redispatch
	retries             	3
	timeout http-request	10s
	timeout queue       	1m
	timeout connect     	10s
	timeout client      	300s
	timeout server      	300s
	timeout http-keep-alive 10s
	timeout check       	10s
	maxconn             	20000

# Useful for debugging, dangerous for production
listen stats
	bind :9000
	mode http
	stats enable
	stats uri /

frontend openshift-api-server
	bind *:6443
	default_backend openshift-api-server
	mode tcp
	option tcplog

backend openshift-api-server
	balance source
	mode tcp
	server master-0 MASTER0IP:6443 check
	server master-1 MASTER1IP:6443 check
	server master-2 MASTER2IP:6443 check
        server bootstrap BOOTSTRAPIP:6443 check

frontend machine-config-server
	bind *:22623
	default_backend machine-config-server
	mode tcp
	option tcplog

backend machine-config-server
	balance source
	mode tcp
        server master-0 MASTER0IP:22623 check
        server master-1 MASTER1IP:22623 check
        server master-2 MASTER2IP:22623 check
        server bootstrap BOOTSTRAPIP:22623 check

frontend ingress-http
	bind *:80
	default_backend ingress-http
	mode tcp
	option tcplog

backend ingress-http
	balance source
	mode tcp
	server worker-0 WORKER0IP:80 check
	server worker-1 WORKER1IP:80 check

frontend ingress-https
	bind *:443
	default_backend ingress-https
	mode tcp
	option tcplog

backend ingress-https
	balance source
	mode tcp
	server worker-0 WORKER0IP:443 check
	server worker-1 WORKER1IP:443 check
EOT


echo "==== install and configure apache"
yum install httpd -y
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf
echo "apache is setup" > /var/www/html/test
service httpd start

echo "==== get openshift install, client, and RHCOS images"
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-4.4.3-x86_64-installer.x86_64.iso
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-4.4.3-x86_64-installer-kernel-x86_64
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz

tar -xvzf openshift-install-linux.tar.gz
tar -xvzf openshift-client-linux.tar.gz

echo "==== create manifests"
mkdir packetinstall
cat <<EOT > packetinstall/install-config.yaml
apiVersion: v1
baseDomain: BASEDOMAIN
compute:
- hyperthreading: Enabled   
  name: worker
  replicas: 0 
controlPlane:
  hyperthreading: Enabled   
  name: master 
  replicas: 3 
metadata:
  name: METADATANAME
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14 
    hostPrefix: 23 
  networkType: OpenShiftSDN
  serviceNetwork: 
  - 172.30.0.0/16
platform:
  none: {} 
fips: false 
pullSecret: 'PULLSECRET'
sshKey: 'SSHKEY'
EOT

sed -i "s/BASEDOMAIN/${BASEDOMAIN}/" packetinstall/install-config.yaml
sed -i "s/METADATANAME/${METADATANAME}/" packetinstall/install-config.yaml
sed -i "s%PULLSECRET%${PULLSECRET}%" packetinstall/install-config.yaml
sed -i "s%SSHKEY%${SSHKEY}%" packetinstall/install-config.yaml

./openshift-install create manifests --dir=packetinstall

sed -i 's/mastersSchedulable: true/mastersSchedulable: false/' packetinstall/manifests/cluster-scheduler-02-config.yml

./openshift-install create ignition-configs --dir=packetinstall


echo "==== Create publicly accessible directory, Copy ignition files, Create iPXE files"

mkdir /var/www/html/packetstrap

cp packetinstall/*.ign /var/www/html/packetstrap/
cp rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img /var/www/html/packetstrap/
cp rhcos-4.4.3-x86_64-installer.x86_64.iso /var/www/html/packetstrap/
cp rhcos-4.4.3-x86_64-installer-kernel-x86_64 /var/www/html/packetstrap/
cp rhcos-4.4.3-x86_64-metal.x86_64.raw.gz /var/www/html/packetstrap/


cat <<EOT > /var/www/html/packetstrap/bootstrap.boot
#!ipxe

kernel http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-kernel-x86_64 ip=dhcp rd.neednet=1 initrd=http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img console=ttyS1,115200n8 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz coreos.inst.ignition_url=http://PUBLICIP:8080/packetstrap/bootstrap.ign
initrd http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img
boot
EOT

cat <<EOT > /var/www/html/packetstrap/master.boot
#!ipxe

kernel http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-kernel-x86_64 ip=dhcp rd.neednet=1 initrd=http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img console=ttyS1,115200n8 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz coreos.inst.ignition_url=http://PUBLICIP:8080/packetstrap/master.ign
initrd http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img
boot
EOT

cat <<EOT > /var/www/html/packetstrap/worker.boot
#!ipxe

kernel http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-kernel-x86_64 ip=dhcp rd.neednet=1 initrd=http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img console=ttyS1,115200n8 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz coreos.inst.ignition_url=http://PUBLICIP:8080/packetstrap/worker.ign
initrd http://PUBLICIP:8080/packetstrap/rhcos-4.4.3-x86_64-installer-initramfs.x86_64.img
boot
EOT


sed -i "s/PUBLICIP/$PUBLICIP/g" /var/www/html/packetstrap/bootstrap.boot
sed -i "s/PUBLICIP/$PUBLICIP/g" /var/www/html/packetstrap/master.boot
sed -i "s/PUBLICIP/$PUBLICIP/g" /var/www/html/packetstrap/worker.boot



echo "==== all done, you can now iPXE servers to:"
echo "       http://${PUBLICIP}:8080/packetstrap/bootstrap.boot"
echo "       http://${PUBLICIP}:8080/packetstrap/master.boot"
echo "       http://${PUBLICIP}:8080/packetstrap/worker.boot"



