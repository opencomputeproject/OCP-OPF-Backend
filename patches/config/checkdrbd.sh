#!/bin/bash
# Script to handle DRBD from keepalived.
DRBDADM="sudo /usr/sbin/drbdadm"
DRBDRESOURCE="cluster"
MOUNTPOINT="/var/lib/iscsi_disks"
status=
role=
cstate=
dstate=

init_status() {
        # start with NOK status
        if [ -z "$status" ]
        then
                status=1
        fi
        role=$( $DRBDADM role $DRBDRESOURCE )
        cstate=$( $DRBDADM cstate $DRBDRESOURCE )
        dstate=$( $DRBDADM dstate $DRBDRESOURCE )
}

set_status() {
        status=$1
        return $status
}

check() {
        # CHECK DRBD
        init_status
        status=1
        # at least UpToDate
        if echo $dstate | grep -q ^UpToDate/
        then
                # Primary + UpToDate
                status=0
        fi
	echo $status
        # Stop checking if already in fault ...
        if [ $status -gt 0 ]
        then
                set_status $status
                return $?
        fi
        # if in warm state,
        # (only if Primary)
#        if [ $status -eq 0 ] && echo "$role" | grep -q ^Primary
#        then
#                echo "Reconnect DRBD"
#                reconnect_drbd
#        fi

        sync
        set_status $status
        return $?
}


set_fault() {
        set_backup
        return $?
}


set_backup() {
        # We must be sure to be in replication and secondary state
        ensure_drbd_secondary
}
set_drbd_secondary() {
	sudo systemctl stop coredhcp
	sudo systemctl stop tftp
        sudo systemctl stop tgt
        sudo umount $MOUNTPOINT
        $DRBDADM disconnect $DRBDRESOURCE
        $DRBDADM secondary $DRBDRESOURCE
        $DRBDADM connect $DRBDRESOURCE
        $DRBDADM secondary $DRBDRESOURCE
        role=`drbdadm role cluster | awk -F"/" '{print $1}'`
        while [ "$role" != "Secondary" ]
        do
                echo "$DRBDADM secondary $DRBDRESOURCE" >> /tmp/titi
                sleep 1
                $DRBDADM secondary $DRBDRESOURCE
		role=`drbdadm role cluster | awk -F"/" '{print $1}'`
        done

        init_status
}


ensure_drbd_secondary() {
        set_drbd_secondary
        if ! is_drbd_secondary
        then
                set_drbd_secondary
                return $?
        fi
}
is_drbd_secondary() {
        init_status
        # If already Secondary and Connected, do nothing ...
        if echo $role | grep -q ^Secondary
        then
                if [ "$cstate" != 'StandAlone' ]
                then
                        return 1
                fi
        fi
        return 0
}

reconnect_drbd() {
        init_status
        if [ "$cstate" = "StandAlone" ]
        then
                $DRBDADM connect $DRBDRESOURCE
        fi
}
# WARNING set_master is called at keepalived start
# So if already in "good" state we must do nothing :)
set_master() {
        init_status
        if ! echo "$role" | grep -q ^Primary
        then
                $DRBDADM disconnect $DRBDRESOURCE
                $DRBDADM primary $DRBDRESOURCE
                init_status
                if ! echo "$role" | grep -q ^Primary
                then
                        $DRBDADM -- --overwrite-data-of-peer primary $DRBDRESOURCE
                        init_status
                        if ! echo "$role" | grep -q ^Primary
                        then
                                return 1
                        fi
                fi
        fi
        if ! awk '{print $2}' /etc/mtab | grep "^$MOUNTPOINT" >/dev/null
        then
                device=$( $DRBDADM sh-dev $DRBDRESOURCE )
                #FSTYPE="ext4"
                #MOUNTOPTS=sync,noauto,noatime,noexec
                fsck.ext4 -pD $device >&2

                if ! sudo mount -t ext4 $device $MOUNTPOINT
                then
                        return 1
                fi
        fi
        sudo systemctl restart tgt
	sudo systemctl restart coredhcp
	sudo systemctl restart tftp
        reconnect_drbd
}

exec 100>/var/tmp/clusterlock.lock || exit 1
flock -n 100 || exit 1
trap 'rm -f /var/tmp/clusterlock.lock' EXIT

case "$1" in
        check)
                check
                exit $?
        ;;
        backup)
                set_backup
                exit $?
        ;;
        fault)
                set_fault
                drbdadm secondary cluster
                exit $?
        ;;
        master)
                set_master
                exit $?
        ;;
esac
