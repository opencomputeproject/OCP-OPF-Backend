#!/bin/bash
# Copyright (c) 2024 Hewlett-Packard Development Company, L.P.
# Copyright (c) 2024 Open Compute Project
# MIT based license

rm -f ./SD/*.gz
rm 6.8-dango.zip
sudo apt -y install debootstrap
sudo apt -y install binutils-aarch64-linux-gnu binfmt-support
sudo apt -y install ccache u-boot-tools libncurses5-dev gcc-aarch64-linux-gnu cpp-aarch64-linux-gnu qemu-user-static qemu-system-arm qemu-utils
sudo apt -y install libncurses5-dev libncurses5

sudo rm -rf BPI-Router-Linux BPI-Router-Images
wget https://github.com/frank-w/BPI-Router-Linux/archive/refs/heads/6.8-dango.zip
unzip 6.8-dango.zip
rm 6.8-dango.zip
mv BPI-Router-Linux-6.8-dango BPI-Router-Linux
cd BPI-Router-Linux
echo "starting build through defconfig"
cp ./arch/arm64/configs/mt7988a_bpi-r4_defconfig ../patches/kernel/mt7988a_bpi-r4_defconfig.bak
cp ../patches/kernel/mt7988a_bpi-r4_defconfig ./arch/arm64/configs/mt7988a_bpi-r4_defconfig
sudo apt install git
checkpRepo=`git log`
if [ "$?" == "128" ]
then
        echo "error"
        git init
        git add *
        git commit -m "initial input"
fi
echo "import configuration"
ls -lta
./build.sh importconfig
./build.sh <<EOF
1
EOF
cp ../patches/kernel/mt7988a_bpi-r4_defconfig.bak ./arch/arm64/configs/mt7988a_bpi-r4_defconfig
cd ..
sudo umount ./build
if [ -f "SD/bpi-r4_6.8.0-rc3main.tar.gz" ]
then
	mv SD/bpi-r4_6.8.0-rc3main.tar.gz SD/bpi-r4_6.8.0-rc3-dango.tar.gz
	mv SD/bpi-r4_6.8.0-rc3main.tar.gz.md5 SD/bpi-r4_6.8.0-rc3-dango.tar.gz.md5
else
	mv SD/bpi-r4_6.8.0-rc3master.tar.gz SD/bpi-r4_6.8.0-rc3-dango.tar.gz
	mv SD/bpi-r4_6.8.0-rc3master.tar.gz.md5 SD/bpi-r4_6.8.0-rc3-dango.tar.gz.md5
fi
exit 0
rm -rf main.zip
rm -rf BPI-Router-Images
wget https://github.com/frank-w/BPI-Router-Images/archive/refs/heads/main.zip
unzip main.zip
rm main.zip
mv BPI-Router-Images-main BPI-Router-Images
cp patches/build/sourcefiles_bpi-r4.conf BPI-Router-Images
cd BPI-Router-Images
rm -f *.gz
rm -f bpi-r4_jammy_6.8.0-rc3-dango.img
cp ../patches/build/buildchroot.sh ./buildchroot.sh
sudo ./buildimg.sh bpi-r4 jammy
