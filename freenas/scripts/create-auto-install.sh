#!/bin/sh
# Author: Kris Moore / iXsystems
# Usage: ./create-auto-install.sh <ISO>
########################################################

# Settings

# DISK name for VM
VMDISK="vtbd0"


########################################################

# Where is the program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

ISO="$1"

# Extract the ISO file
MD=`mdconfig -a -t vnode $ISO`
if [ $? -ne 0 ] ; then exit 1; fi
mkdir isomnt
mkdir isodir

mount_cd9660 /dev/$MD isomnt
if [ $? -ne 0 ] ; then exit 1; fi

echo "Copying ISO data..."
tar cvf - -C ./isomnt . 2>/dev/null | tar xvpf - -C ./isodir 2>/dev/null
if [ $? -ne 0 ] ; then exit 1; fi
sleep 2

umount -f isomnt
if [ $? -ne 0 ] ; then exit 1; fi

rmdir isomnt
mdconfig -d -u $MD
if [ $? -ne 0 ] ; then exit 1; fi

# Now extract the UZIP file
MD=`mdconfig -a -t vnode isodir/data/base.ufs.uzip`
if [ $? -ne 0 ] ; then exit 1; fi
mkdir uzipmnt
mkdir uzipdir

mount -o ro /dev/${MD}.uzip uzipmnt
if [ $? -ne 0 ] ; then exit 1; fi

echo "Copying uzip data..."
tar cvf - -C ./uzipmnt . 2>/dev/null | tar xvpf - -C ./uzipdir 2>/dev/null
if [ $? -ne 0 ] ; then exit 1; fi
sleep 2

umount -f uzipmnt
if [ $? -ne 0 ] ; then exit 1; fi

rmdir uzipmnt
mdconfig -d -u $MD
if [ $? -ne 0 ] ; then exit 1; fi

# Now massage the install image
###############################################

# Setup install to be automated
sed -i '' "s|/etc/install.sh|/etc/install.sh ${VMDISK};/sbin/halt -p|g" uzipdir/etc/rc
if [ $? -ne 0 ] ; then exit 1; fi

# Now setup ATF to run at first boot after install
sed -i '' "s|zpool scrub freenas-boot|cp -r /atf /tmp/data/atf;cp /atf/rc.local /tmp/data/etc/rc.local;zpool scrub freenas-boot|g" uzipdir/conf/default/etc/install.sh
if [ $? -ne 0 ] ; then exit 1; fi

# Copy over the ATF scripts
cp -r ${PROGDIR}/atf uzipdir/
if [ $? -ne 0 ] ; then exit 1; fi

echo "#### Creating uzip file ####"
# Figure out disk size and set up a vnode
UFSFILE=base.ufs
sync
cd uzipdir
DIRSIZE=$(($(du -kd 0 | cut -f 1)))
FSSIZE=$(($DIRSIZE + $DIRSIZE + 55000))
cd ..
rc_halt "dd if=/dev/zero of=${UFSFILE} bs=1k count=${FSSIZE}"

MD=$(mdconfig -a -t vnode -f ${UFSFILE})
rc_halt "newfs -b 4096 -n -o space /dev/${MD}"

mkdir uzipmnt
sleep 2
mount -o noatime /dev/${MD} uzipmnt
if [ $? -ne 0 ] ; then exit 1; fi

# Now copy the usr filesystem
echo "Creating base.ufs... Please wait..."
cd uzipdir
find . -print -depth 2>/dev/null | cpio -dump -v ../uzipmnt 2>/dev/null
cd ..

# Remove old usrmnt and remount
umount -f /dev/${MD}

sleep 1
chflags -R noschg uzipdir
rm -rf uzipdir
rc_halt "mdconfig -d -u $MD"

echo "Compressing with uzip..."
rc_halt "mkuzip -v -s 65536 -o base.ufs.uzip ${UFSFILE}" >/dev/null 2>/dev/null

# Cleanup after ourselves
rmdir uzipmnt
rm base.ufs

rc_halt "mv base.ufs.uzip isodir/data/base.ufs.uzip"

# Create the new ISO file
grub-mkrescue -o freenas-auto.iso isodir -- -volid FreeNAS

# Cleanup old iso dir
rm -rf isodir
