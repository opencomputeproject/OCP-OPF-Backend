#!/bin/bash
#sudo apt-get install qemu-user-static debootstrap binfmt-support

#debian
distro_debian=(buster bullseye bookworm)
name=debian
#distro=bullseye
distro=bookworm

#ubuntu
distro_ubuntu=(focal jammy)
#name=ubuntu
#distro=jammy #22.04

#arch=armhf
arch=arm64
#arch=amd64
#arch=x86_64

ramdisksize=4G

#sudo apt install debootstrap qemu-user-static
function checkpkg(){
	echo "checking for needed packages..."
# we build natively so no need to check for qemu anymore
#	for pkg in debootstrap qemu-arm-static qemu-aarch64-static; do
#		which $pkg >/dev/null;
#		if [[ $? -ne 0 ]];then
#			echo "$pkg missing";
#			exit 1;
#		fi;
#	done
}

checkpkg

if [[ -n "$1" ]];then
	echo "\$1:"$1
	if [[ "$1" =~ armhf|arm64 ]];then
		echo "setting arch"
		arch=$1
	fi
fi

if [[ -n "$2" ]];then
	echo "\$2:"$2

	isdebian=$(echo ${distro_debian[@]} | grep -o "$2" | wc -w)
	isubuntu=$(echo ${distro_ubuntu[@]} | grep -o "$2" | wc -w)

	echo "isdebian:$isdebian,isubuntu:$isubuntu"
	if [[ $isdebian -ne 0 ]] || [[ $isubuntu -ne 0 ]];then
		echo "setting distro"
		distro=$2
		if [[ $isubuntu -ne 0 ]];then
			name="ubuntu"
		fi
	else
		echo "invalid distro $2"
		exit 1
	fi
fi

echo "create chroot '${name} ${distro}' for ${arch}"

#set -x
targetdir=$(pwd)/${name}_${distro}_${arch}
content=$(ls -A $targetdir 2>/dev/null)

if [[ -e $targetdir ]] && [[ "$content" ]]; then echo "$targetdir already exists - aborting";exit;fi

mkdir -p $targetdir
sudo chown root:root $targetdir

if [[ "$ramdisksize" != "" ]];
then
	mount | grep '\s'$targetdir'\s' &>/dev/null #$?=0 found;1 not found
	if [[ $? -ne 0 ]];then
		echo "mounting tmpfs for building..."
		sudo mount -t tmpfs -o size=$ramdisksize none $targetdir
	fi
fi

#mount | grep 'proc\|sys'
echo debootstrap --arch=$arch --foreign $distro $targetdir
sudo debootstrap --arch=$arch --foreign $distro $targetdir
case "$arch" in
	"armhf")
		sudo cp /usr/bin/qemu-arm-static $targetdir/usr/bin/
	;;
	"arm64")
	#for r64 use
	# We build natively no need to install qemu anymore
	#	sudo cp /usr/bin/qemu-aarch64-static $targetdir/usr/bin/
	#	sudo cp ../../qemu/qemu-5.0.0/build/aarch64-linux-user/qemu-aarch64  $targetdir/usr/bin/qemu-aarch64-static
	;;
	"amd64")
		;;
	*) echo "unsupported arch $arch";;
esac
sudo cp /etc/resolv.conf $targetdir/etc
LANG=C

#sudo mount -t proc none $targetdir/proc/
#sudo mount -t sysfs sys $targetdir/sys/
#sudo mount -o bind /dev $targetdir/dev/
sudo chroot $targetdir /debootstrap/debootstrap --second-stage
ret=$?
if [[ $ret -ne 0 ]];then
	#sudo umount $targetdir/proc/
	#sudo umount $targetdir/sys/
	#sudo rm -rf $targetdir/*
	exit $ret;
fi

echo 'root:bananapi' | sudo chroot $targetdir /usr/sbin/chpasswd

langcode=de
if [[ "$name" == "debian" ]];then
trees="main contrib non-free non-free-firmware"
if [[ "$distro" =~ bookworm ]];then trees="$trees non-free-firmware"; fi
sudo chroot $targetdir tee "/etc/apt/sources.list" > /dev/null <<EOF
deb http://ftp.$langcode.debian.org/debian $distro $trees
deb-src http://ftp.$langcode.debian.org/debian $distro $trees
deb http://ftp.$langcode.debian.org/debian $distro-updates $trees
deb-src http://ftp.$langcode.debian.org/debian $distro-updates $trees
deb http://security.debian.org/debian-security ${distro}-security $trees
deb-src http://security.debian.org/debian-security ${distro}-security $trees
EOF
else
trees="main universe restricted multiverse"
sudo chroot $targetdir tee "/etc/apt/sources.list" > /dev/null <<EOF
deb http://ports.ubuntu.com/ubuntu-ports/ $distro $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro $trees
deb http://ports.ubuntu.com/ubuntu-ports/ $distro-security $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro-security $trees
deb http://ports.ubuntu.com/ubuntu-ports/ $distro-updates $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro-updates $trees
deb http://ports.ubuntu.com/ubuntu-ports/ $distro-backports $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro-backports $trees
EOF
fi
#sudo chroot $targetdir cat "/etc/apt/sources.list"

sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y openssh-server"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y golang-1.20"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y gcc"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y build-essential"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y tgt"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y git"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y drbd-utils"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y glances"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y nvme-cli"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y net-tools"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y dialog"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y keepalived"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y lsof"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y vim"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y rpm2cpio"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y cpio"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y wget"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y gunzip"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y fdisk"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y build-essential cmake git libjson-c-dev libwebsockets-dev"
sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y nfs-kernel-server"
sudo chroot $targetdir bash -c "apt update; apt install -y build-essential cmake git libjson-c-dev libwebsockets-dev"
sudo chroot $targetdir bash -c "cd /root; git clone https://github.com/tsl0922/ttyd"
sudo chroot $targetdir bash -c "cd /root; cd ttyd; mkdir build; cd build; cmake ..; make; cp ttyd /usr/bin"
sudo chroot $targetdir bash -c "cd /root; git clone -b discover https://github.com/vejmarie/coredhcp"
sudo chroot $targetdir bash -c "cp /root/coredhcp/cmds/coredhcp/config.yml.example /root/coredhcp/cmds/coredhcp/config.yml"
sudo chroot $targetdir bash -c "ln -s /usr/lib/go-1.20/bin/go /usr/bin/go"
sudo chroot $targetdir bash -c "cd /root/coredhcp/cmds/coredhcp; /usr/bin/go build"
sudo chroot $targetdir bash -c 'adduser --disabled-password --gecos "" keepalived_script'
sudo chroot $targetdir bash -c 'echo "keepalived_script ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/sbin/drbdadm, /usr/bin/systemctl" >> /etc/sudoers'
cp ../patches/go/startCoreDHCP.sh $targetdir/usr/bin
cp ../patches/go/startTFTP.sh $targetdir/usr/bin
cp ../patches/config/configSystem.sh $targetdir/usr/bin
cp ../patches/config/configPreBoot.sh $targetdir/usr/bin/
cp ../patches/config/sb-recover.sh $targetdir/usr/bin
mkdir $targetdir/usr/bin/rom
mkdir $targetdir/usr/bin/rom/hpe
mkdir $targetdir/var/lib/rom/
mkdir $targetdir/var/lib/rom/configs
cp ../patches/rom/hpe/download.sh $targetdir/usr/bin/rom/hpe
cp ../patches/rom/hpe/process.sh $targetdir/usr/bin/rom/hpe
cp ../patches/rom/hpe/gen11.json $targetdir/var/lib/rom/configs
chmod 755 $targetdir/usr/bin/startCoreDHCP.sh
chmod 755 $targetdir/usr/bin/startTFTP.sh
chmod 755 $targetdir/usr/bin/configSystem.sh
chmod 755 $targetdir/usr/bin/configPreBoot.sh
chmod 755 $targetdir/usr/bin/sb-recover.sh
chmod 755 $targetdir/usr/bin/rom/hpe/process.sh
chmod 755 $targetdir/usr/bin/rom/hpe/download.sh
cp ../patches/systemd/coredhcp.service $targetdir/etc/systemd/system/
cp ../patches/systemd/tftp.service $targetdir/etc/systemd/system/
cp ../patches/systemd/tgt.service $targetdir/usr/lib/systemd/system/
cp ../patches/systemd/configfirstboot.service $targetdir/usr/lib/systemd/system/
cp ../patches/systemd/tgt.service $targetdir/etc/systemd/system/multi-user.target.wants
cp ../patches/systemd/tgt.service $targetdir/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/
cp ../patches/systemd/configsystem.service $targetdir/usr/lib/systemd/system/
cp ../patches/config/checkdrbd.sh $targetdir/etc/keepalived
sudo chroot $targetdir bash -c 'chown 1000:1000 /etc/keepalived/checkdrbd.sh'
sudo chroot $targetdir bash -c 'chmod 755 /etc/keepalived/checkdrbd.sh'
cp ../patches/config/keepalived.conf $targetdir/etc/keepalived
cp ../patches/config/sb-recover.sh $targetdir/usr/bin
sudo chroot $targetdir bash -c "cd /root; git clone -b discover https://github.com/vejmarie/golang-tftp-example"
sudo chroot $targetdir bash -c "cd /root/golang-tftp-example/src/gotftpd ; /usr/bin/go build"
sudo chroot $targetdir bash -c "systemctl disable coredhcp"
sudo chroot $targetdir bash -c "systemctl disable tftp"
sudo chroot $targetdir bash -c "systemctl disable tgt"
sudo chroot $targetdir bash -c "systemctl enable configfirstboot"
sudo chroot $targetdir bash -c "systemctl enable configsystem"
sudo chroot $targetdir bash -c "systemctl disable hostapd"
sudo chroot $targetdir bash -c "systemctl disable keepalived"
sudo chroot $targetdir bash -c "systemctl disable systemd-networkd-wait-online"
rm -rf $targetdir/etc/systemd/network/*
cp ../patches/network/* $targetdir/etc/systemd/network
cp ../patches/config/global_common.conf $targetdir/etc/drbd.d
cp ../patches/config/cluster.res $targetdir/etc/drbd.d
# mv $targetdir/etc/machine-id $targetdir/etc/machine-id.org

echo 'PermitRootLogin=yes'| sudo tee -a $targetdir/etc/ssh/sshd_config

echo 'bpi'| sudo tee $targetdir/etc/hostname

(
cd $targetdir
sudo tar -czf ../${distro}_${arch}.tar.gz .
)

if [[ "$ramdisksize" != "" ]];
then
	echo "umounting tmpfs..."
	sudo umount $targetdir
else
	sudo rm -rf $targetdir/.
fi
