# OCP-OPF-Backend

## Introduction

This repository contains proof of concept of an automated firmware distribution stack. The primary goal is to centralize all firmware in one place, and start clients machines from it. For that purpose we start from the BMC which boots by issuing a DHCP/TFTP boot request (using VLAN) retrieve a FIT image and mount from the network a block storage area. Then following firmware are cascaded based on hardware discovery performed by the BMC (ROM, PCIe end points etc ...)   

## Build and supported hardware

The stack is modular and is currently based on a plugin extension of coredhcp project (https://github.com/coredhcp/coredhcp) as everything starts from the network. It will then spawn multiple systemd services (so core O/S must be currently systemd compatible and is based for the PoC on ubuntu Jammy) which includes iSCSI target servers, TFTP server, NFS services and many to come. 

The build script is currently supporting a single hardware target platform which is the BananaPI-R4 hardware (https://wiki.banana-pi.org/Banana_Pi_BPI-R4). Further hardware could be added, but we focused our initial effort on a low cost easy to source dev systems which can be cost effective.

The build system is expected to be an x86 64 bits linux machine based on debian or ubuntu (ideally jammy). It will cross compile for the target and the build will:
- Build a fix kernel version (6.8)
- Grab a u-boot pre-built image from ttps://github.com/frank-w/
- Build a rootfs
  - Install the Firmware services related patches to the rootfs
- Assemble an SD image
The output is a ready to deploy SD image for BananaPi-R4

## Deployment

To deploy the image just simply use the dd command to deploy the image to a target SD as an example after having uncompressed the image into bpi-r4_jammy_6.8.0 file

dd if=bpi-r4_jammy_6.8.0 of=/dev/rdisk2 bs=1M status=progress

## Testing

Insert the SD card into the Bananapi-R4 and boot it.
Watch for the boot process and answer the configuration questions
- Cluster node number must be set to 1 into a standalone configuration or 1/2 into a clustering mode (please read the wiki as documentation)
- Http proxy must be specified if your network requires a proxy

## Limitations

Initial boots take a lot of time as standard ROM image are loaded from the network and setup in a way to be readily available for client BMC to starts host machines. A way to validate that the whole configuration has been done is to check that the coredhcp service runs by issuing the systemctl status coredhcp command at regular interval.

lanbr0 must have an IP address for initial boots to work. So you must connect your bananapi-R4 to a network and the pi-r4 is going to retrieve its IP through DHCP request (no static IP configuration supported yet)

## switch setup

After initial boot the switch needs to have a default firmware image to serve (aka OpenBMC bootable image). Build one which includes iscsi support and TFTP FIT image ready to boot. Pack it into a single tar image by following wiki instructions (to come) and drag and drop it to the integrated webui. Make it default by selecting the menu entry.

## client setup

On any supported clients (currently HPE Proliant Gen11 machines and initial Gen12 DL320/DL340) setup the u-boot environment to boot from the bananapi-r4 by connecting the iLO ethernet adatper to it and set these environment variables

- setenv loadaddr 0x50000000
- setenv vlan 100
- Then issue a dhcp and bootm command.
