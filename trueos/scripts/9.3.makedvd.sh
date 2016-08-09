#!/bin/sh
#        Author: Kris Moore
#   Description: Creates the ISO file
#     Copyright: 2010 PC-BSD Software / iXsystems
############################################################################

# Where is the build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/trueos.cfg

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

rc_halt "mkdir -p ${ISODISTDIR}/packages"
rc_halt "mount_nullfs ${METAPKGDIR} ${ISODISTDIR}/packages"

# Set the file-date
fDate="-`date '+%Y-%m-%d'`"

# Base file name
if [ "$SYSBUILD" = "trueos" ] ; then
  bFile="TrueOS-Server-${fDate}-${FARCH}"
  bTitle="TrueOS"
  brand="trueos"
else
  bFile="TrueOS-Desktop-${fDate}-${FARCH}"
  bTitle="TrueOS"
  brand="trueos"
fi
export bFile

# Set the trueos-media-details file marker on this media
echo "TrueOS ${TRUEOSVER} "$ARCH" INSTALL DVD - `date`" > ${PDESTDIR9}/trueos-media-details
touch ${PDESTDIR9}/trueos-media-local

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

LABEL="TRUEOS_INSTALL"
publisher="The TrueOS Project.  http://www.trueos.org/"
echo "Running makefs..."
echo "/dev/iso9660/$LABEL / cd9660 ro 0 0" > ${PDESTDIR9}/etc/fstab

# Set some initial loader.conf values
cp ${PDESTDIR9}/boot/loader.conf ${PDESTDIR9}/boot/loader.conf.orig

cat >${PDESTDIR9}/boot/loader.conf << EOF
vfs.root.mountfrom="cd9660:/dev/iso9660/$LABEL"
loader_menu_title="Welcome to $bTitle"
loader_logo="$brand"
loader_brand="$brand"
EOF

# Throw back in the pre-supplied settings
cat ${PDESTDIR9}/boot/loader.conf.orig >> ${PDESTDIR9}/boot/loader.conf

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

# Create the .torrent
mktorrent -a udp://tracker.coppersurfer.tk:6969 -w http://download.trueos.org/iso/master/amd64/${bFile}-DVD.iso ${bFile}-DVD.iso

######
# Create the USB images
######

OUTFILE="${PROGDIR}/iso/${bFile}-USB.img"

# Set the trueos-media-details file marker on this media
echo "TrueOS ${TRUEOSVER} "$ARCH" INSTALL USB - `date`" > ${PDESTDIR9}/trueos-media-details
touch ${PDESTDIR9}/trueos-media-local

echo "Creating IMG..."
echo '/dev/ufs/TRUEOS_INSTALL / ufs ro,noatime 1 1' > ${PDESTDIR9}/etc/fstab

# Make EFI system partition (should be done with makefs in the future)
cd ${PROGDIR}/iso

# Set some initial loader.conf values
cat >${PDESTDIR9}/boot/loader.conf << EOF
vfs.root.mountfrom="ufs:/dev/ufs/$LABEL"
loader_menu_title="Welcome to $bTitle"
loader_logo="$brand"
loader_brand="$brand"
EOF

# Throw back in the pre-supplied settings
cat ${PDESTDIR9}/boot/loader.conf.orig >> ${PDESTDIR9}/boot/loader.conf

echo "Running makefs..."
rc_halt "makefs -B little -o label=${LABEL} ${OUTFILE}.part ${PDESTDIR9}"
rm ${PDESTDIR9}/etc/fstab

# Create the USB image now
echo "Running mkimg..."
rc_halt "mkimg -s gpt -b ${PDESTDIR9}/boot/pmbr -p efi:=${PDESTDIR9}/boot/boot1.efifat -p freebsd-boot:=${PDESTDIR9}/boot/gptboot -p freebsd-ufs:=${OUTFILE}.part -p freebsd-swap::1M -o ${OUTFILE}"
rm ${OUTFILE}.part
rm ${FAT_FILE}

rc_halt "umount ${ISODISTDIR}/packages"

# Run MD5 command
cd ${PROGDIR}/iso
md5 -q ${OUTFILE} >${OUTFILE}.md5
sha256 -q ${OUTFILE} >${OUTFILE}.sha256
if [ ! -e "latest.img" ] ; then
  ln -s `basename ${OUTFILE}` latest.img
  ln -s `basename ${OUTFILE}.md5` latest.img.md5
  ln -s `basename ${OUTFILE}.sha256` latest.img.sha256
fi

# Create the .torrent
mktorrent -a udp://tracker.coppersurfer.tk:6969 -w http://download.trueos.org/iso/master/amd64/${OUTFILE} ${OUTFILE}

exit 0
