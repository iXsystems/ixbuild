#!/usr/bin/env sh
# Author: Kris Moore / iXsystems
# Usage: ./create-auto-install.sh <ISO>
########################################################

# Settings

# DISK name for VM
VMDISK="ada0"

########################################################

# Where is the program installed
PROGDIR="`realpath ${0} | sed 's|/create-auto-install.sh||g'`/../" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

ISO="$1"

# Extract the ISO file
MD=`mdconfig -a -t vnode $ISO`
if [ $? -ne 0 ] ; then exit 1; fi
mkdir isomnt 2>/dev/null
mkdir isodir 2>/dev/null

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

# Load geom_uzip if necessary
kldstat | grep -q 'geom_uzip'
if [ $? -ne 0 ] ; then
  kldload geom_uzip
fi

# Set kernel to boot in serial mode
sed -i '' "s|/boot/kernel/kernel|/boot/kernel/kernel -D -h|g" isodir/boot/grub/grub.cfg
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
sed -i '' "s|/etc/install.sh|/etc/install.sh ${VMDISK};/sbin/mount -t zfs freenas-boot/ROOT/default /mnt;/rescue/chroot /mnt /usr/local/bin/sqlite3 /data/freenas-v1.db 'update system_advanced set adv_serialconsole = 1';/sbin/umount /mnt;/sbin/halt -p|g" uzipdir/etc/rc
if [ $? -ne 0 ] ; then exit 1; fi

# Now setup ATF to run at first boot after install
sed -i '' "s|# zpool scrub freenas-boot|cp -r /atf /tmp/data/atf;mkdir -p /tmp/data/conf/default/etc;cp /atf/rc.local /tmp/data/conf/default/etc/rc.local;chmod 755 /tmp/data/conf/default/etc/rc.local;zpool scrub freenas-boot|g" uzipdir/conf/default/etc/install.sh
if [ $? -ne 0 ] ; then exit 1; fi
sed -i '' "s|# zpool scrub freenas-boot|cp -r /atf /tmp/data/atf;mkdir -p /tmp/data/conf/default/etc;cp /atf/rc.local /tmp/data/conf/default/etc/rc.local;chmod 755 /tmp/data/conf/default/etc/rc.local;zpool scrub freenas-boot|g" uzipdir/etc/install.sh
if [ $? -ne 0 ] ; then exit 1; fi

# Set serial mode
sed -i '' 's|# And now move the backup files back in place|chroot \${_mnt} sed -i "" "s;kernel/kernel;kernel/kernel -D -h;g" /boot/grub/grub.cfg|g' uzipdir/conf/default/etc/install.sh
if [ $? -ne 0 ] ; then exit 1; fi

# Copy over the ATF scripts
cp -r ${PROGDIR}/atf uzipdir/
if [ $? -ne 0 ] ; then exit 1; fi

# Copy over custom rc.local if it exists
if [ -e "/atf/rc.local" ] ; then
cp /atf/rc.local uzipdir/atf/
fi

# Copy over custom etc overlay if it exists
if [ -d "/atf/etc" ] ; then
cp -R /atf/etc uzipdir/atf/
fi

# Set the IP address in rc.local
sed -i '' "s|%%IP%%|${FNASTESTIP}|g" uzipdir/atf/rc.local

# Check if we have a truenas license dir
if [ -e "/etc/truenas-license" ] ; then
  cp /etc/truenas-license uzipdir/atf/
fi

echo "#### Creating uzip file ####"
# Figure out disk size and set up a vnode
UFSFILE=base.ufs
sync
cd uzipdir
DIRSIZE=$(($(du -kd 0 | cut -f 1)))
FSSIZE=$(($DIRSIZE + $DIRSIZE + 1000000))
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
if [ -e "$BUILDTAG.iso" ] ; then
  rm $BUILDTAG.iso
fi

if [ "$FLAVOR" = "TRUENAS" ] ; then
  VOLID="TrueNAS"
else
  VOLID="FreeNAS"
fi

grub-mkrescue -o $BUILDTAG.iso isodir -- -volid ${VOLID}_INSTALL
if [ $? -ne 0 ] ; then exit 1; fi

# Cleanup old iso dir
rm -rf isodir
