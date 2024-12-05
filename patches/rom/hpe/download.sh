URI="https://downloads.linux.hpe.com/SDR/repo"
FWPP="fwpp-gen11"
REPO="/var/lib/iscsi_disks/roms"
mkdir $REPO
\rm -rf $REPO/work
mkdir $REPO/work
if [ ! -d "$REPO/repo" ]
then
        mkdir $REPO/repo
fi
wget --no-check-certificate -O $REPO/work/repomd.xml $URI/$FWPP/current/repodata/repomd.xml
index=`cat $REPO/work/repomd.xml | grep filelists.xml | sed "s/<location href=\"repodata\///" | sed "s/\"\/>//g" | sed 's/^[ \t]*//'`
wget --no-check-certificate -O $REPO/work/index.xml.gz $URI/$FWPP/current/repodata/$index
gunzip $REPO/work/index.xml.gz
filelist=`grep firmware-system $REPO/work/index.xml | grep signed.flash`
for i in $filelist
do
        rpm=`echo $i | awk -F"/" '{ print $5}'`
        firmware=`echo $rpm | awk -F"-" '{ print $1"-"$2"-"$3 }'`
        archs=`cat $REPO/work/index.xml | grep $firmware | grep arch`
        arch=`echo $archs[0] | awk '{ print $4}' | sed 's/arch=\"//g' | sed 's/\">//g'`
        rpm=$rpm.$arch.rpm
        if [ ! -f "$REPO/repo/$rpm" ]
        then
                echo "$rpm not present"
                wget  --no-check-certificate -O$REPO/repo/$rpm $URI/$FWPP/current/$rpm
        else
                echo "rpm soon available $rpm"
        fi
done
