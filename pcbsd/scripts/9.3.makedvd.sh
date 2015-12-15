#!/bin/sh
#        Author: Kris Moore
#   Description: Creates the ISO file
#     Copyright: 2010 PC-BSD Software / iXsystems
############################################################################

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/pcbsd.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

echo "Building DVD images.."

ISODISTDIR="${PDESTDIR9}/dist"

# Remove archive files
if [ -d "${ISODISTDIR}" ] ; then
  echo "Removing ${ISODISTDIR}"
  rm -rf ${ISODISTDIR}
fi
mkdir ${ISODISTDIR}

echo "Copying dist files.."
cp ${DISTDIR}/* ${ISODISTDIR}/
# Nuke the src.txz, its 110MB~ and 99.9% of users don't need it
rm ${ISODISTDIR}/src.txz

rc_halt "mkdir -p ${ISODISTDIR}/packages"
rc_halt "mount_nullfs ${METAPKGDIR} ${ISODISTDIR}/packages"

# Set the file-date
fDate="-`date '+%m-%d-%Y'`"

# Base file name
if [ "$SYSBUILD" = "trueos" ] ; then
  bFile="TRUEOS${ISOVER}${fDate}-${FARCH}"
  bTitle="TrueOS"
  brand="trueos"
else
  bFile="PCBSD${ISOVER}${fDate}-${FARCH}"
  bTitle="PC-BSD"
  brand="pcbsd"
fi
export bFile

# Set the pcbsd-media-details file marker on this media
echo "TrueOS ${PCBSDVER} "$ARCH" INSTALL DVD - `date`" > ${PDESTDIR9}/pcbsd-media-details
touch ${PDESTDIR9}/pcbsd-media-local

echo "Creating ISO..."
# Stolen from FreeBSD's build scripts
# This is highly x86-centric and will be used directly below.
bootable="-o bootimage=i386;$4/boot/cdboot -o no-emul-boot"

# Make EFI system partition (should be done with makefs in the future)
rc_halt "dd if=/dev/zero of=efiboot.img bs=4k count=500"
device=`mdconfig -a -t vnode -f efiboot.img`
rc_halt "newfs_msdos -F 12 -m 0xf8 /dev/$device"
rc_nohalt "mkdir efi"
rc_halt "mount -t msdosfs /dev/$device efi"
rc_halt "mkdir -p efi/efi/boot"
rc_halt "cp ${PDESTDIR9}/boot/loader.efi efi/efi/boot/bootx64.efi"
rc_halt "umount efi"
rc_halt "rmdir efi"
rc_halt "mdconfig -d -u $device"
bootable="-o bootimage=i386;efiboot.img -o no-emul-boot $bootable"

LABEL="PCBSD_INSTALL"
publisher="The PC-BSD Project.  http://www.pcbsd.org/"
echo "Running makefs..."
echo "/dev/iso9660/$LABEL / cd9660 ro 0 0" > ${PDESTDIR9}/etc/fstab

# Set some initial loader.conf values
cp ${PDESTDIR9}/boot/loader.conf ${PDESTDIR9}/boot/loader.conf.orig
cat >>${PDESTDIR9}/boot/loader.conf << EOF
vfs.root.mountfrom="cd9660:/dev/iso9660/$LABEL"
loader_menu_title="Welcome to $bTitle"
loader_brand="$brand"
EOF
makefs -t cd9660 $bootable -o rockridge -o label=$LABEL -o publisher="$publisher" ${PROGDIR}/iso/${bFile}-DVD.iso ${PDESTDIR9}
rm ${PDESTDIR9}/etc/fstab
rm -f efiboot.img


# Run MD5 command
cd ${PROGDIR}/iso
md5 -q ${bFile}-DVD.iso >${bFile}-DVD.iso.md5
sha256 -q ${bFile}-DVD.iso >${bFile}-DVD.iso.sha256
if [ ! -e "latest.iso" ] ; then
  ln -s ${bFile}-DVD.iso latest.iso
  ln -s ${bFile}-DVD.iso.md5 latest.iso.md5
  ln -s ${bFile}-DVD.iso.sha256 latest.iso.sha256
fi

######
# Create the USB images
######

OUTFILE="${PROGDIR}/iso/${bFile}-USB.img"

# Set the pcbsd-media-details file marker on this media
echo "TrueOS ${PCBSDVER} "$ARCH" INSTALL USB - `date`" > ${PDESTDIR9}/pcbsd-media-details
touch ${PDESTDIR9}/pcbsd-media-local

echo "Creating IMG..."
echo '/dev/ufs/PCBSD_Install / ufs ro,noatime 1 1' > ${PDESTDIR9}/etc/fstab
# Set some initial loader.conf values
cp ${PDESTDIR9}/boot/loader.conf.orig ${PDESTDIR9}/boot/loader.conf
cat >>${PDESTDIR9}/boot/loader.conf << EOF
vfs.root.mountfrom="ufs:/dev/ufs/$LABEL"
loader_menu_title="Welcome to $bTitle"
loader_brand="$brand"
EOF
echo "Running makefs..."
rc_halt "makefs -B little -o label=${LABEL} ${OUTFILE}.part ${PDESTDIR9}"
rm ${PDESTDIR9}/etc/fstab

# Lets create the custom FAT partition for EFI boot
# Generate 800K FAT image
FAT_FILE=${PDESTDIR9}/boot/bootx64.efifat

dd if=/dev/zero of=$FAT_FILE bs=512 count=1600
DEVICE=`mdconfig -a -f $FAT_FILE`
newfs_msdos -F 12 -L EFI $DEVICE
cd ${PROGDIR}/iso
mkdir stub
mount -t msdosfs /dev/$DEVICE stub

# Create and bless a directory for the boot loader
mkdir -p stub/efi/boot
cp ${PDESTDIR9}/boot/boot1.efi stub/efi/boot/bootx64.efi

umount stub
mdconfig -d -u $DEVICE
rmdir stub


echo "Running mkimg..."
rc_halt "mkimg -s gpt -b ${PDESTDIR9}/boot/pmbr -p efi:=${FAT_FILE} -p freebsd-boot:=${PDESTDIR9}/boot/gptboot -p freebsd-ufs:=${OUTFILE}.part -p freebsd-swap::1M -o ${OUTFILE}"
rm ${OUTFILE}.part

rc_halt "umount ${ISODISTDIR}/packages"

# Run MD5 command
cd ${PROGDIR}/iso
md5 -q ${OUTFILE} >${OUTFILE}.md5
sha256 -q ${OUTFILE} >${OUTFILE}.sha256
if [ ! -e "latest.img" ] ; then
  ln -s ${OUTFILE} latest.img
  ln -s ${OUTFILE}.md5 latest.img.md5
  ln -s ${OUTFILE}.sha256 latest.img.sha256
fi


exit 0
