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

# Remove the symbols from kernel.txz
rc_halt "mkdir ${ISODISTDIR}/kerntmp"
rc_halt "tar xvpf ${ISODISTDIR}/kernel.txz -C ${ISODISTDIR}/kerntmp"
rc_halt "rm ${ISODISTDIR}/kerntmp/boot/kernel/*.symbols"
rc_halt "tar cvJf ${ISODISTDIR}/kernel.txz -C ${ISODISTDIR}/kerntmp ."
rc_halt "rm -rf ${ISODISTDIR}/kerntmp"

rc_halt "mkdir -p ${ISODISTDIR}/packages"
rc_halt "mount_nullfs ${METAPKGDIR} ${ISODISTDIR}/packages"

# Set the file-date
fDate="-`date '+%m-%d-%Y'`"

# Base file name
if [ "$SYSBUILD" = "trueos" ] ; then
  bFile="TRUEOS${ISOVER}${fDate}-${FARCH}"
else
  bFile="PCBSD${ISOVER}${fDate}-${FARCH}"
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
dd if=/dev/zero of=efiboot.img bs=4k count=100
device=`mdconfig -a -t vnode -f efiboot.img`
newfs_msdos -F 12 -m 0xf8 /dev/$device
mkdir efi
mount -t msdosfs /dev/$device efi
mkdir -p efi/efi/boot
cp ${PDESTDIR9}/boot/loader.efi efi/efi/boot/bootx64.efi
umount efi
rmdir efi
mdconfig -d -u $device
bootable="-o bootimage=i386;efiboot.img -o no-emul-boot $bootable"

LABEL="PCBSD_INSTALL"
publisher="The PC-BSD Project.  http://www.pcbsd.org/"
echo "/dev/iso9660/$LABEL / cd9660 ro 0 0" > ${PDESTDIR9}/etc/fstab
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

# Set the pcbsd-media-details file marker on this media
echo "TrueOS ${PCBSDVER} "$ARCH" INSTALL USB - `date`" > ${PDESTDIR9}/pcbsd-media-details
touch ${PDESTDIR9}/pcbsd-media-local

echo "Creating IMG..."

OUTFILE="${PROGDIR}/iso/${bFile}-USB.iso"


echo '/dev/ufs/PCBSD_Install / ufs ro,noatime 1 1' > ${PDESTDIR9}/etc/fstab
makefs -B little -o label=PCBSD_Install ${OUTFILE}.part ${PDESTDIR9}
if [ $? -ne 0 ]; then
        echo "makefs failed"
        exit 1
fi
rm ${PDESTDIR9}/etc/fstab

mkimg -s gpt -b ${PDESTDIR9}/boot/pmbr -p efi:=${PDESTDIR9}/boot/boot1.efifat -p freebsd-boot:=${PDESTDIR9}/boot/gptboot -p freebsd-ufs:=${OUTFILE}.part -p freebsd-swap::1M -o ${OUTFILE}
rm ${OUTFILE}.part

rc_halt "umount ${ISODISTDIR}/packages"

exit 0
