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
echo "TrueOS ${PCBSDVER} "$ARCH" INSTALL DVD/USB - `date`" > ${PDESTDIR9}/pcbsd-media-details

# Use GRUB to create the hybrid DVD/USB image
echo "Creating ISO..."
grub-mkrescue -o ${PROGDIR}/iso/${bFile}-DVD-USB.iso ${PDESTDIR9} -- -volid "PCBSD_INSTALL"
if [ $? -ne 0 ] ; then
   exit_err "Failed running grub-mkrescue"
fi

# Run MD5 command
cd ${PROGDIR}/iso
md5 -q ${bFile}-DVD-USB.iso >${bFile}-DVD-USB.iso.md5
sha256 -q ${bFile}-DVD-USB.iso >${bFile}-DVD-USB.iso.sha256
ln -s ${bFile}-DVD-USB.iso latest.iso
ln -s ${bFile}-DVD-USB.iso.md5 latest.iso.md5
ln -s ${bFile}-DVD-USB.iso.sha256 latest.iso.sha256

rc_halt "umount ${ISODISTDIR}/packages"

exit 0
