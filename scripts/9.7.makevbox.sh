#!/bin/sh
#        Author: Kris Moore
#   Description: Creates a vbox disk image
#     Copyright: 2011 PC-BSD Software / iXsystems
############################################################################

# Check if we have sourced the variables yet
# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Source the config file
. ${PROGDIR}/pcbsd.cfg

cd ${PROGDIR}/scripts


if [ -z ${PDESTDIR} ]
then
  echo "ERROR: PDESTDIR is still unset!"
  exit 1
fi

# VFS FILE
MFSFILE="${PROGDIR}/iso/PCBSD${PCBSDVER}-${FARCH}.img"
ISODIR="${PDESTDIR9}-vm"


VPKGLIST="pcbsd-base misc/pcbsd-meta-kde archivers/unzip archivers/unrar pcbsd-meta-virtualboxguest pcbsd-meta-vwmareguest"

# Cleanup any failed build
umount ${ISODIR} 2>/dev/null
umount ${ISODIR}-tmp 2>/dev/null
rmdir ${ISODIR}-tmp
sleep 1

# Create the tmp dir we will be using
mk_tmpfs_wrkdir ${ISODIR}
mkdir ${ISODIR}-tmp


# Extract the ISO file
DVDFILE=`ls ${PROGDIR}/iso/PCBSD*.iso`
if [ ! -e "$DVDFILE" ] ; then
  echo "No such ISO file: $DVDFILE"
  exit 1
fi

# Make sure bhyve is loaded
kldstat -n vmm >/dev/null 2>/dev/null
if [ $? -ne 0 ] ; then
   kldload vmm
fi

echo "Copying file-system contents to memory..."
MD=`mdconfig -a -t vnode -f ${DVDFILE}`
rc_halt "mount_cd9660 /dev/$MD ${ISODIR}-tmp"
tar cvf - -C ${ISODIR}-tmp . 2>/dev/null | tar xvf - -C ${ISODIR} 2>/dev/null
if [ $? -ne 0 ] ; then
  exit_err "Failed running grub-mkrescue"
fi
rc_halt "umount /dev/$MD"
rc_halt "mdconfig -d -u $MD"

echo "Extracting /root and /etc"
rc_halt "tar xvf ${ISODIR}/uzip/root-dist.txz -C ${ISODIR}/root" >/dev/null 2>/dev/null
rc_halt "tar xvf ${ISODIR}/uzip/etc-dist.txz -C ${ISODIR}/etc" >/dev/null 2>/dev/null

# Copy the bhyve ttys / gettytab
rc_halt "cp ${PROGDIR}/scripts/pre-installs/ttys ${ISODIR}/etc/"
rc_halt "cp ${PROGDIR}/scripts/pre-installs/gettytab ${ISODIR}/etc/"

# Re-compression of /root and /etc
echo "Re-compressing /root and /etc"
rc_halt "tar cvJf ${ISODIR}/uzip/root-dist.txz -C ${ISODIR}/root ." >/dev/null 2>/dev/null
rc_halt "tar cvJf ${ISODIR}/uzip/etc-dist.txz -C ${ISODIR}/etc ." >/dev/null 2>/dev/null
rc_halt "rm -rf ${ISODIR}/root"
rc_halt "mkdir ${ISODIR}/root"

# Now loop through and generate VM disk images based upon supplied configs
for cfg in `ls ${PROGDIR}/scripts/pre-installs/*.cfg`
do
  pName="`basename $cfg | sed 's|.cfg||g'`"

  # Create the filesystem backend file
  echo "Creating $MFSFILE"
  truncate -s 50000M $MFSFILE

  # Copy the pc-sysinstall config
  rc_halt "cp $cfg ${ISODIR}/pc-sysinstall.cfg"
   
  # Setup the auto-install stuff
  echo "pc_config: /pc-sysinstall.cfg
shutdown_cmd: shutdown -p now
confirm_install: NO" > ${ISODIR}/pc-autoinstall.conf

  # Use GRUB to create the hybrid DVD/USB image
  echo "Creating ISO..."
  echo "/dev/iso9660/PCBSD_INSTALL / cd9660 ro 0 0" > ${ISODIR}/etc/fstab
  bootable="-o bootimage=i386;$4/boot/cdboot -o no-emul-boot"
  makefs -t cd9660 $bootable -o rockridge -o label=PCBSD_INSTALL -o publisher="PCBSD" ${PROGDIR}/iso/VMAUTO.iso ${ISODIR}
  if [ $? -ne 0 ] ; then
   exit_err "Failed running makefs"
  fi

  # Run BHYVE now

  # Just in case the install hung, we don't need to be waiting for over an hour
  (sleep 3600 && bhyve --destroy --vm=vminstall) &
  kPid=$!
  sh /usr/share/examples/bhyve/vmrun.sh -c 2 -m 2048M -d ${MFSFILE} -i -I ${PROGDIR}/iso/VMAUTO.iso vminstall
  kill -9 $kPid

  VDIFILE="${PROGDIR}/iso/PCBSD${PCBSDVER}-${FARCH}-${pName}-VBOX.vdi"
  VMDKFILE="${PROGDIR}/iso/PCBSD${PCBSDVER}-${FARCH}-${pName}-VMWARE.vmdk"
  RAWFILE="${PROGDIR}/iso/PCBSD${PCBSDVER}-${FARCH}-${pName}-VMWARE.raw"

  # Create the disk images from the raw file now
 
  # Do VirtualBox now
  rm ${VDIFILE} 2>/dev/null
  rm ${VDIFILE}.xz 2>/dev/null
  rc_halt "VBoxManage convertfromraw --format VDI ${MFSFILE} ${VDIFILE}"
  rc_halt "xz ${VDIFILE}"
  rc_halt "chmod 644 ${VDIFILE}.xz"

  # Do VMWARE now
  rm ${VMDKFILE} 2>/dev/null
  rm ${VMDKFILE}.xz 2>/dev/null
  rc_halt "VBoxManage convertfromraw --format VMDK ${MFSFILE} ${VMDKFILE}"
  rc_halt "xz ${VMDKFILE}"
  rc_halt "chmod 644 ${VMDKFILE}.xz"

  # Do RAW now
  rm ${RAWFILE} 2>/dev/null
  rm ${RAWFILE}.xz 2>/dev/null
  rc_halt "mv $MFSFILE $RAWFILE"
  rc_halt "xz ${RAWFILE}"
  rc_halt "chmod 644 ${RAWFILE}.xz"

  # Run MD5 command
  cd ${PROGDIR}/iso
  md5 -q ${VDIFILE}.xz >${VDIFILE}.xz.md5
  sha256 -q ${VDIFILE}.xz >${VDIFILE}.xz.sha256
  md5 -q ${VMDKFILE}.xz >${VMDKFILE}.xz.md5
  sha256 -q ${VMDKFILE}.xz >${VMDKFILE}.xz.sha256
  md5 -q ${RAWFILE}.xz >${RAWFILE}.xz.md5
  sha256 -q ${RAWFILE}.xz >${RAWFILE}.xz.sha256

  # Cleanup
  rm ${PROGDIR}/iso/VMAUTO.iso
done

# Cleanup tempfs
umount ${ISODIR} 2>/dev/null
exit 0
