#!/bin/bash
# turn off kwown hosts hashing
sed -i '/^    HashKnownHosts/s/ yes/ no/' /etc/ssh/ssh_config
# We must set the Mac from the usable networking port
if [ ! -d "/var/switch" ]
then
	mkdir /var/switch
fi
interfaces="eth1 lan1 lan2 lan3 wan eth2 lanbr0"
for i in $interfaces
do
	if [ ! -f "/var/switch/$i" ]
	then
		mac=`python3 -c 'import os; print(":".join(["{:02x}".format(x) for x in b"\02x" + os.urandom(4)]))'`
		echo "$mac" > /var/switch/$i
	else
		mac=`cat /var/switch/$i`
	fi
	ip link set dev $i address $mac
done
ip link add link eth1 name eth1.100 type vlan id 100
ip link set lan1 master lanbr0
ip link set lan2 master lanbr0
ip link set lan3 master lanbr0
ip link set wan master lanbr0
ip link set eth1 master lanbr0
# Do not send redirect on upstream link
echo 0 > /proc/sys/net/ipv4/conf/eth2/send_redirects
ip link set eth2 master lanbr0
ip link add vlanbr0 type bridge
ip link set lan1.100 master vlanbr0
ip link set lan2.100 master vlanbr0
ip link set lan3.100 master vlanbr0
ip link set wan.100 master vlanbr0
ip link set eth1.100 master vlanbr0
bridge vlan add dev lan1.100 vid 100
bridge vlan del dev lan1.100 vid 1 pvid egress untagged
bridge vlan add dev lan2.100 vid 100
bridge vlan del dev lan2.100 vid 1 pvid egress untagged
bridge vlan add dev lan3.100 vid 100
bridge vlan del dev lan3.100 vid 1 pvid egress untagged
bridge vlan add dev wan.100 vid 100
bridge vlan del dev wan.100 vid 1 pvid egress untagged
bridge vlan add dev eth1.100 vid 100
bridge vlan del dev eth1.100 vid 1 pvid egress untagged
# bridge vlan del dev eth1 vid 1 untagged pvid
bridge vlan del dev eth1 vid 1 pvid egress untagged
bridge vlan add dev vlanbr0 vid 100 tagged self

clusterID=`cat /etc/clusterid`
myip=$(( $clusterID + 1 ))

echo 1 > /proc/sys/net/ipv4/conf/all/arp_announce
echo 1 > /proc/sys/net/ipv4/conf/all/proxy_arp
echo 1 > /proc/sys/net/ipv4/conf/all/proxy_arp_pvlan
echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
# Do not send redirect, we are in Host mode , not Router mode
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

ifconfig eth1 up
ifconfig eth2 up
ifconfig lan1.100 up
ifconfig lan2.100 up
ifconfig lan3.100 up
ifconfig wan.100 up
ifconfig eth1.100 up
ifconfig vlanbr0 10.0.100.$myip netmask 255.255.255.0 up
clusterID=`cat /etc/clusterid`

# We must initialize the storage
if [ ! -f /etc/storageConfigured ]
then
	if [ "$clusterID" == "1" ] || [ "$clusterID" == "0" ]
	then
	# Ok we must set the Cluster ID 1 to master and
	# format the drives
		drbdadm up cluster
	        drbdadm primary --force cluster
	        mkfs.ext4 /dev/drbd0
	else
		drbdadm up cluster
                drbdadm secondary cluster
	fi
	# we must wait for synchronization before integrating the cluster
	# but only on the node which is not synced
	diskState=`drbdadm status |head -2 | tail -1 | awk -F":" '{print $2}'`
	if [ "$diskState" != "UpToDate" ]
	then
		replication=`drbdadm status | grep replication | awk -F":" '{print $2}' | awk '{print $1}'`
		while [ "$replication" == "SyncSource" ] || [ "$replication" == "SyncTarget" ]
		do
			sleep 10
			replication=`drbdadm status | grep replication | awk -F":" '{print $2}' | awk '{print $1}'`
		done
	fi
	if [ ! -d /var/lib/iscsi_disks ]
	then
	       mkdir /var/lib/iscsi_disks
	fi
	if [ ! -L /var/ftpd ]
	then
		mkdir /var/lib/iscsi_disks/tftp
		ln -s /var/lib/iscsi_disks/tftp /var/ftpd
	fi
	if [ ! -L /var/rpms ]
	then
		mkdir /var/lib/iscsi_disks/rpms
		ln -s /var/lib/iscsi_disks/rpms /var/rpms
	fi

	role=`drbdadm role cluster | awk -F"/" '{print $1}'`
	if [ "$role" != "Secondary" ]
	then
		mount /dev/drbd0 /var/lib/iscsi_disks
		cp -rf /root/coredhcp /var/lib/iscsi_disks
		cp -rf /root/golang-tftp-example /var/lib/iscsi_disks
		/usr/bin/rom/hpe/download.sh
		/usr/bin/rom/hpe/process.sh
		mkdir /var/lib/iscsi_disks/rpms
		mkdir /var/lib/iscsi_disks/tftp
		mkdir /var/lib/iscsi_disks/target
                mkdir /var/lib/iscsi_disks/target/tmp
		mkdir /var/lib/iscsi_disks/images
		umount /var/lib/iscsi_disks
	fi
else
	drbdadm up cluster
fi
touch /etc/storageConfigured
systemctl start keepalived
