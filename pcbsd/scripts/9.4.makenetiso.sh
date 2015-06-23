#!/bin/sh
#        Author: Kris Moore
#   Description: Creates the network install ISO file
#     Copyright: 2015 PC-BSD Software / iXsystems
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
touch ${PDESTDIR9}/pcbsd-media-network

# Use GRUB to create the hybrid BIOS/UEFI DVD/USB image
echo "Creating ISO..."
grub-mkrescue -o ${PROGDIR}/iso/${bFile}-netinstall.iso ${PDESTDIR9} -- -volid "PCBSD_INSTALL"
if [ $? -ne 0 ] ; then
   exit_err "Failed running grub-mkrescue"
fi

# Run MD5 command
cd ${PROGDIR}/iso
md5 -q ${bFile}-netinstall.iso >${bFile}-netinstall.iso.md5
sha256 -q ${bFile}-netinstall.iso >${bFile}-netinstall.iso.sha256
if [ ! -e "latest.iso" ] ; then
  ln -s ${bFile}-netinstall.iso latest.iso
  ln -s ${bFile}-netinstall.iso.md5 latest.iso.md5
  ln -s ${bFile}-netinstall.iso.sha256 latest.iso.sha256
fi

exit 0
