#!/bin/bash
REPO="/var/lib/iscsi_disks/roms"
cd $REPO/repo
if [ ! -d "images" ]
then
        mkdir images
fi
currentRpms=`ls *.rpm`
for i in $currentRpms
do
        targetName=`echo $i | sed 's/\.x86_64\.rpm//g'`
        if [ ! -f "images/$targetName" ]
        then
                mkdir tmp
                cd tmp
                rpm2cpio ../$i | cpio -idmv
                cp usr/lib/x86_64-linux-gnu/$targetName/*.signed.flash ../images
                image=`ls -A1 usr/lib/x86_64-linux-gnu/$targetName/*.signed.flash`
                imageSize=`ls -lta usr/lib/x86_64-linux-gnu/$targetName/*.signed.flash | awk '{ print $5 }'`
                # 33554432
                headerSize=$(( ${imageSize} - 33554432 ))
                if [ $headerSize -lt 0 ]
                then
                        headerSize=$(( ${imageSize} - 16777216 ))
                fi
                echo $headerSize
                UnsignedName=`echo $image | sed 's/\.signed\.flash/\.mtd/'`
                dd iflag=skip_bytes if=$image of=$UnsignedName skip=$headerSize
                cp $UnsignedName ../images
                touch ../images/$targetName
                cd ..
                rm -rf tmp

        fi
done
