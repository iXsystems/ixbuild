#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
fi


# Set the default FreeNAS testing IP address
if [ -z "${FNASTESTIP}" ] ; then
  FNASTESTIP="192.168.56.100"
  export FNASTESTIP
fi

# Set local location of FreeNAS build
if [ -n "$BUILDTAG" ] ; then
  FNASBDIR="/$BUILDTAG"
else
  FNASBDIR="/freenas"
fi
export FNASBDIR

# Figure out the ISO name
echo "Finding ISO file..."
if [ -d "${FNASBDIR}/objs" ] ; then
  ISOFILE=`find ${FNASBDIR}/objs | grep '\.iso$' | head -n 1`
elif [ -d "${FNASBDIR}/_BE/release" ] ; then
  ISOFILE=`find ${FNASBDIR}/_BE/release | grep '\.iso$' | head -n 1`
else
  if [ -n "$1" ] ; then
    ISOFILE=`find ${1} | grep '\.iso$' | head -n 1`
  else
    ISOFILE=`find ${PROGDIR}/../objs | grep '\.iso$' | head -n 1`
  fi
fi

# If no ISO found
if [ -z "$ISOFILE" ] ; then
  exit_err "Failed locating ISO file, did 'make release' work?"
fi

# Is this TrueNAS or FreeNAS?
echo $ISOFILE | grep -q "TrueNAS"
if [ $? -eq 0 ] ; then
   export FLAVOR="TRUENAS"
else
   export FLAVOR="FREENAS"
fi

echo "Using ISO: $ISOFILE"

# Create the automatic ISO installer
cd ${PROGDIR}/tmp
${PROGDIR}/scripts/create-auto-install.sh ${ISOFILE}
if [ $? -ne 0 ] ; then
  exit_err "Failed creating auto-install ISO!"
fi

# We now run virtualbox headless
# This is because grub-bhyve can't boot FreeBSD on root/zfs
# Once bhyve matures we can switch this back over
kldunload vmm 2>/dev/null >/dev/null
# Remove bridge0/tap0 so vbox bridge mode works
ifconfig bridge0 destroy >/dev/null 2>/dev/null
ifconfig tap0 destroy >/dev/null 2>/dev/null

# Get the default interface
iface=`netstat -f inet -nrW | grep '^default' | awk '{ print $6 }'`

# Load up VBOX
kldstat | grep -q vboxdrv
if [ $? -eq 0 ] ; then
  kldload vboxdrv
fi
kldstat | grep -q vboxnet
if [ $? -eq 0 ] ; then
  service vboxnet onestart
fi

# Now lets spin-up vbox and do an installation
######################################################
MFSFILE="${PROGDIR}/tmp/freenas-disk0.img"
echo "Creating $MFSFILE"
rc_halt "VBoxManage createhd --filename ${MFSFILE}.vdi --size 50000"

VM="vminstall"
# Remove any crashed / old VM
VBoxManage unregistervm $VM >/dev/null 2>/dev/null
rm -rf "/root/VirtualBox VMs/vminstall" >/dev/null 2>/dev/null

# Copy ISO over to /root in case we need to grab it from jenkins node later
if [ "$FLAVOR" = "TRUENAS" ] ; then
  cp ${PROGDIR}/tmp/freenas-auto.iso /root/truenas-auto.iso
else
  cp ${PROGDIR}/tmp/freenas-auto.iso /root/freenas-auto.iso
fi

# Remove from the vbox registry
VBoxManage closemedium dvd ${PROGDIR}/tmp/freenas-auto.iso >/dev/null 2>/dev/null

# Create the VM in virtualbox
rc_halt "VBoxManage createvm --name $VM --ostype FreeBSD_64 --register"
rc_halt "VBoxManage storagectl $VM --name SATA --add sata --controller IntelAhci"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 0 --device 0 --type hdd --medium ${MFSFILE}.vdi"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type dvddrive --medium ${PROGDIR}/tmp/freenas-auto.iso"
rc_halt "VBoxManage modifyvm $VM --cpus 2 --ioapic on --boot1 disk --memory 4096 --vram 12"
rc_nohalt "VBoxManage hostonlyif remove vboxnet0"
rc_halt "VBoxManage hostonlyif create"
rc_halt "VBoxManage modifyvm $VM --nic1 hostonly"
rc_halt "VBoxManage modifyvm $VM --hostonlyadapter1 vboxnet0"
rc_halt "VBoxManage modifyvm $VM --macaddress1 auto"
rc_halt "VBoxManage modifyvm $VM --nicpromisc1 allow-all"
if [ -n "$BRIDGEIP" ] ; then
  # Switch to bridged mode
  DEFAULTNIC=`netstat -nr | grep "^default" | awk '{print $4}'`
  rc_halt "VBoxManage modifyvm $VM --nictype1 82540EM"
  rc_halt "VBoxManage modifyvm $VM --nic2 bridged"
  rc_halt "VBoxManage modifyvm $VM --bridgeadapter2 ${DEFAULTNIC}"
  rc_halt "VBoxManage modifyvm $VM --nicpromisc2 allow-all"
else
  # Fallback to NAT
  rc_halt "VBoxManage modifyvm $VM --nictype1 82540EM"
  rc_halt "VBoxManage modifyvm $VM --nic2 nat"
fi
rc_halt "VBoxManage modifyvm $VM --macaddress2 auto"
rc_halt "VBoxManage modifyvm $VM --nictype2 82540EM"
rc_halt "VBoxManage modifyvm $VM --pae off"
rc_halt "VBoxManage modifyvm $VM --usb on"

# Setup serial output
rc_halt "VBoxManage modifyvm $VM --uart1 0x3F8 4"
rc_halt "VBoxManage modifyvm $VM --uartmode1 file /tmp/vboxpipe"

# Just in case the install hung, we don't need to be waiting for over an hour
echo "Performing VM installation..."
count=0

# Unload VB
VBoxManage controlvm vminstall poweroff >/dev/null 2>/dev/null

# Start the VM
daemon -p /tmp/vminstall.pid vboxheadless -startvm "$VM" --vrde off

# Wait for initial bhyve startup
count=0
while :
do
  if [ ! -e "/tmp/vminstall.pid" ] ; then break; fi

  pgrep -qF /tmp/vminstall.pid
  if [ $? -ne 0 ] ; then
        break;
  fi

  count=`expr $count + 1`
  if [ $count -gt 20 ] ; then break; fi
  echo -e ".\c"

  sleep 30
done

# Make sure VM is shutdown
VBoxManage controlvm vminstall poweroff >/dev/null 2>/dev/null

# Remove from the vbox registry
VBoxManage closemedium dvd ${PROGDIR}/tmp/freenas-auto.iso >/dev/null 2>/dev/null

# Set the DVD drive to empty
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive"

# Display output of VM serial mode
echo "OUTPUT FROM INSTALLATION CONSOLE..."
echo "---------------------------------------------"
cat /tmp/vboxpipe
echo ""

# Check that this device seemed to install properly
dSize=`du -m ${MFSFILE}.vdi | awk '{print $1}'`
if [ $dSize -lt 10 ] ; then
   # if the disk image is too small, installation didn't work, bail out!
   echo "VM install failed!"
   exit 1
fi

sync
sleep 2

echo "VM installation successful!"
sleep 1

# Exit for now, can't do live run until grub-bhyve is updated
#exit 0

echo "Starting testing now!"

# Attach extra disks to the VM for testing
rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk1 --size 20000"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type hdd --medium ${MFSFILE}.disk1"
rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk2 --size 20000"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 2 --device 0 --type hdd --medium ${MFSFILE}.disk2"

# Get rid of old output file
if [ -e "/tmp/vboxpipe" ] ; then
  rm /tmp/vboxpipe
fi

echo "Running Installed System..."
daemon -p /tmp/vminstall.pid vboxheadless -startvm "$VM" --vrde off

# Give a minute to boot, should be ready for REST calls now
sleep 120

# Run the REST tests now
cd ${PROGDIR}/scripts

if [ -n "$FREENASLEGACY" ] ; then
  ./9.10-create-tests.sh 2>&1 | tee >/tmp/fnas-create-tests.log
  ./9.10-update-tests.sh 2>&1 | tee >/tmp/fnas-update-tests.log
  ./9.10-delete-tests.sh 2>&1 | tee >/tmp/fnas-delete-tests.log
  res=$?
else
  ./10-tests.sh 2>&1 | tee >/tmp/fnas-tests.log
  res=$?
fi

# Shutdown that VM
VBoxManage controlvm vminstall poweroff >/dev/null 2>/dev/null
sync

# Delete the VM
VBoxManage unregistervm $VM --delete

echo ""
echo "Output from console during runtime tests:"
echo "-----------------------------------------"
cat /tmp/vboxpipe

echo ""
echo "Output from REST API calls:"
echo "-----------------------------------------"
cat /tmp/fnas-tests.log

exit $res
