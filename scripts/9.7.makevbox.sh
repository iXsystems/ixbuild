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
rmdir ${ISODIR}-tmp 2>/dev/null
sleep 1

# Create the tmp dir we will be using
mk_tmpfs_wrkdir ${ISODIR}
mkdir ${ISODIR}-tmp


# Extract the ISO file
DVDFILE=`ls ${PROGDIR}/iso/PCBSD*DVD-USB.iso`
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
rc_halt "rmdir ${ISODIR}-tmp"

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

  # Use makefs to create the image
  echo "Creating ISO..."
  echo "kern.geom.label.disk_ident.enable=0" >> ${ISODIR}/boot/loader.conf
  echo "kern.geom.label.gptid.enable=0" >> ${ISODIR}/boot/loader.conf
  echo "kern.geom.label.ufsid.enable=0" >> ${ISODIR}/boot/loader.conf
  echo "/dev/iso9660/PCBSD_INSTALL / cd9660 ro 0 0" > ${ISODIR}/etc/fstab
  bootable="-o bootimage=i386;$4/boot/cdboot -o no-emul-boot"
  makefs -t cd9660 $bootable -o rockridge -o label=PCBSD_INSTALL -o publisher="PCBSD" ${PROGDIR}/iso/VMAUTO.iso ${ISODIR}
  if [ $? -ne 0 ] ; then
   exit_err "Failed running makefs"
  fi

  # Run BHYVE now
  sync
  sleep 15

  # Just in case the install hung, we don't need to be waiting for over an hour
  echo "Running bhyve for installation to $MFSFILE..."
  count=0
  daemon -f -p /tmp/vminstall.pid sh /usr/share/examples/bhyve/vmrun.sh -c 2 -m 2048M -d ${MFSFILE} -i -I ${PROGDIR}/iso/VMAUTO.iso vminstall
  while :
  do
    if [ ! -e "/tmp/vminstall.pid" ] ; then break; fi

    pgrep -qF /tmp/vminstall.pid
    if [ $? -ne 0 ] ; then
          break;
    fi

    count=`expr $count + 1`
    if [ $count -gt 360 ] ; then bhyve --destroy --vm=vminstall ; fi
    echo -e ".\c"

    sleep 10
  done

  # Check that this device seemed to install properly
  dSize=`du -m ${MFSFILE} | awk '{print $1}'`
  if [ $dSize -lt 10 ] ; then
     # if the disk image is too small, something didn't work, bail out!
     echo "bhyve install failed!"

     # Cleanup tempfs
     umount ${ISODIR} 2>/dev/null
     rmdir ${ISODIR}
     exit 1
  fi

  OVAFILE="${PROGDIR}/iso/PCBSD${ISOVER}-${FARCH}-${pName}.ova"
  VDIFILE="${PROGDIR}/iso/PCBSD${ISOVER}-${FARCH}-${pName}.vdi"
  VMDKFILE="${PROGDIR}/iso/PCBSD${ISOVER}-${FARCH}-${pName}.vmdk"
  RAWFILE="${PROGDIR}/iso/PCBSD${ISOVER}-${FARCH}-${pName}.raw"

  # Create the VDI
  rm ${VDIFILE} 2>/dev/null
  rm ${VDIFILE}.xz 2>/dev/null
  rc_halt "VBoxManage convertfromraw --format VDI ${MFSFILE} ${VDIFILE}"

  # Create the OVA file now
  rm ${OVAFILE} 2>/dev/null
  rm ${OVAFILE}.xz 2>/dev/null
  VM="$pName"
  # Remove any crashed / old VM
  VBoxManage unregistervm $VM --delete >/dev/null 2>/dev/null

  rc_halt "VBoxManage createvm --name $VM --ostype FreeBSD_64 --register"
  rc_halt "VBoxManage storagectl $VM --name IDE --add ide --controller PIIX4"
  rc_halt "VBoxManage storageattach $VM --storagectl IDE --port 0 --device 0 --type hdd --medium ${VDIFILE}"
  rc_halt "VBoxManage modifyvm $VM --ioapic on --boot1 disk --memory 1024 --vram 12"
  rc_halt "VBoxManage modifyvm $VM --nic1 nat"
  rc_halt "VBoxManage modifyvm $VM --macaddress1 auto"
  rc_halt "VBoxManage modifyvm $VM --nictype1 82540EM"
  rc_halt "VBoxManage modifyvm $VM --pae off"
  rc_halt "VBoxManage modifyvm $VM --usb on"
  rc_halt "VBoxManage modifyvm $VM --audio oss"
  rc_halt "VBoxManage modifyvm $VM --audiocontroller ac97"
  rc_halt "VBoxManage export $VM -o $OVAFILE"
  rc_halt "VBoxManage unregistervm $VM --delete"
  rc_halt "chmod 644 $OVAFILE"

  # Create the VDI
  rm ${VDIFILE} 2>/dev/null
  rm ${VDIFILE}.xz 2>/dev/null
  rc_halt "VBoxManage convertfromraw --format VDI ${MFSFILE} ${VDIFILE}"
  rc_halt "pixz ${VDIFILE}"
  rc_halt "chmod 644 ${VDIFILE}.xz"

  # Create the VMDK
  rm ${VMDKFILE} 2>/dev/null
  rm ${VMDKFILE}.xz 2>/dev/null
  rc_halt "VBoxManage convertfromraw --format VMDK ${MFSFILE} ${VMDKFILE}"
  rc_halt "pixz ${VMDKFILE}"
  rc_halt "chmod 644 ${VMDKFILE}.xz"

  # Do RAW now
  rm ${RAWFILE} 2>/dev/null
  rm ${RAWFILE}.xz 2>/dev/null
  rc_halt "mv $MFSFILE $RAWFILE"
  rc_halt "pixz ${RAWFILE}"
  rc_halt "chmod 644 ${RAWFILE}.xz"

  # Run MD5 command
  cd ${PROGDIR}/iso
  md5 -q ${OVAFILE} >${OVAFILE}.md5
  sha256 -q ${OVAFILE} >${OVAFILE}.sha256
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
rmdir ${ISODIR}
exit 0
