#!/bin/bash

# mkdir /var/lib/iscsi_disks
# mount /dev/drbd0 /var/lib/iscsi_disks

# if [ ! -d /var/lib/iscsi_disks ]
# then
#	mkdir /var/lib/iscsi_disks
# fi
# if [ ! -d /var/ftpd ]
# then
#	mkdir /var/ftpd
# fi
touch /var/ftpd/boot.mtd
touch /var/lib/iscsi_disks/iscsi.tgt
systemctl enable coredhcp
systemctl enable tftp
cd /var/lib/iscsi_disks/coredhcp/cmds/coredhcp
./coredhcp

