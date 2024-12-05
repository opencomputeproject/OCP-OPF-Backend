#!/bin/bash
if [ ! -f /etc/clusterConfigured ]
then
systemctl disable hostapd
driveList=`nvme list | tail -n +3 | awk '{ print $1 }'`
if [ "${#driveList[@]}" == "1" ]
then
        # we must stop drbd first
	nvme format -f -s0 $driveList
	dd if=/dev/zero of=$driveList bs=1024 count=1024
	modprobe drbd
fi
welcome=`dialog --msgbox "System is not configured ! Please answer the following questions" 10 40 --output-fd 1`
ID=3
message="Cluster member ID [ 1(master) or 2]"
while [ "$ID" != "1" ] && [ "$ID" != "2" ] 
do
ID=`dialog --inputbox "$message" 10 40 --output-fd 1`
message="Wrong answer: Please enter an ID between [0 None - 1(master) or 2]"
done
message="Please define http(s) proxy if any"
proxy=`dialog --inputbox "$message" 10 40 --output-fd 1`
echo "http_proxy=\"${proxy}\"" >> /etc/environment
echo "https_proxy=\"${proxy}\"" >> /etc/environment
echo cluster$ID > /etc/hostname
hostname cluster$ID
echo $ID > /etc/clusterid
echo "10.0.100.2 cluster1" > /etc/hosts
echo "10.0.100.3 cluster2" >> /etc/hosts
drbdadm create-md cluster
touch /etc/clusterConfigured
else
	modprobe drbd
fi
