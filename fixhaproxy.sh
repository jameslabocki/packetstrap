MASTER0IP=
MASTER1IP=
MASTER2IP=
BOOTSTRAPIP=
WORKER0IP=
WORKER1IP=

sed -i "s/MASTER0IP/${MASTER0IP}/" /etc/haproxy/haproxy.cfg 
sed -i "s/MASTER1IP/${MASTER1IP}/" /etc/haproxy/haproxy.cfg 
sed -i "s/MASTER2IP/${MASTER2IP}/" /etc/haproxy/haproxy.cfg 
sed -i "s/BOOTSTRAPIP/${BOOTSTRAPIP}/" /etc/haproxy/haproxy.cfg 
sed -i "s/WORKER0IP/${WORKER0IP}/" /etc/haproxy/haproxy.cfg 
sed -i "s/WORKER1IP/${WORKER1IP}/" /etc/haproxy/haproxy.cfg 
service haproxy restart

