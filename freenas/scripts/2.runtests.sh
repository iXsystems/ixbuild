#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
fi

# Figure out the ISO name
ISOFILE=`find /tmp/fnasb/_BE/release | grep \.iso$`

# Create the automatic ISO installer
cd ${PROGDIR}/tmp
${PROGDIR}/scripts/create-auto-install.sh ${ISOFILE}
if [ $? -ne 0 ] ; then
  exit_err "Failed creating auto-install ISO!"
fi

# Lets check status of "tap0" devices
iface=`netstat -f inet -nrW | grep '^default' | awk '{ print $6 }'`
ifconfig tap0 >/dev/null 2>/dev/null
if [ $? -ne 0 ] ; then
  ifconfig tap0 create
  sysctl net.link.tap.up_on_open=1
  ifconfig bridge0 create
  ifconfig bridge0 addm ${iface} addm tap0
  ifconfig bridge0 up
fi

# Now lets spin-up bhyve and do an installation
######################################################
MFSFILE="${PROGDIR}/tmp/freenas-disk0.img"
echo "Creating $MFSFILE"
rc_halt "truncate -s 5000M $MFSFILE"

cp ${PROGDIR}/tmp/freenas-auto.iso /root/

# Just in case the install hung, we don't need to be waiting for over an hour
echo "Performing bhyve installation..."
count=0

# Unload VB
VBoxManage controlvm vminstall poweroff >/dev/null 2>/dev/null
kldunload vboxdrv 2>/dev/null
kldunload vboxnetflt 2>/dev/null
kldunload vboxnetadp 2>/dev/null

kldstat | grep -q "vmm"
if [ $? -ne 0 ] ; then
  kldload vmm
fi

# Start grub-bhyve
bhyvectl --destroy --vm=vminstall >/dev/null 2>/dev/null
echo "(hd0) ${MFSFILE}
(cd0) ${PROGDIR}/tmp/freenas-auto.iso" > ${PROGDIR}/tmp/device.map

# We run the bhyve commands in a seperate screen session, so that they can run
# in jenkins / save output
echo "#!/bin/sh
count=0

grub-bhyve -m ${PROGDIR}/tmp/device.map -r cd0 -M 2048M vminstall
sync
sleep 2

daemon -p /tmp/vminstall.pid bhyve -AI -H -P -s 0:0,hostbridge -s 1:0,lpc -s 2:0,virtio-net,tap0 -s 3:0,virtio-blk,${MFSFILE} -s 4:0,ahci-cd,${PROGDIR}/tmp/freenas-auto.iso -l com1,stdio -c 4 -m 2048M vminstall

# Wait for initial bhyve startup
while :
do
  if [ ! -e "/tmp/vminstall.pid" ] ; then break; fi

  pgrep -qF /tmp/vminstall.pid
  if [ \$? -ne 0 ] ; then
        break;
  fi

  count=\`expr \$count + 1\`
  if [ \$count -gt 20 ] ; then break; fi
  echo -e \".\c\"

  sleep 30
done

# Cleanup the old VM
bhyvectl --destroy --vm=vminstall
"> ${PROGDIR}/tmp/screenvm.sh
chmod 755 ${PROGDIR}/tmp/screenvm.sh

echo "Running bhyve in screen session, will display when finished..."
screen -Dm -L -S vmscreen ${PROGDIR}/tmp/screenvm.sh

# Display output of screen command
cat flush
echo ""

# Check that this device seemed to install properly
dSize=`du -m ${MFSFILE} | awk '{print $1}'`
if [ $dSize -lt 10 ] ; then
   # if the disk image is too small, installation didn't work, bail out!
   echo "bhyve install failed!"
   exit 1
fi

sync
sleep 2

echo "Bhyve installation successful!"
sleep 1

# Exit for now, can't do live run until grub-bhyve is updated
#exit 0

echo "Starting testing now!"

# We now switch from bhyve to virtualbox headless
# This is because grub-bhyve can't boot FreeBSD on root/zfs
# Once bhyve matures we can switch this back over
kldunload vmm
kldload vboxdrv
kldload vboxnetflt
kldload vboxnetadp

# Create the VDI
rm ${MFSFILE}.vdi 2>/dev/null
rc_halt "VBoxManage convertfromraw --format VDI ${MFSFILE} ${MFSFILE}.vdi"

VM="vminstall"
# Remove any crashed / old VM
VBoxManage unregistervm $VM --delete >/dev/null 2>/dev/null
rm -rf "/root/VirtualBox VMs/vminstall" >/dev/null 2>/dev/null
          
# Create the VM in virtualbox
rc_halt "VBoxManage createvm --name $VM --ostype FreeBSD_64 --register"
rc_halt "VBoxManage storagectl $VM --name IDE --add ide --controller PIIX4"
rc_halt "VBoxManage storageattach $VM --storagectl IDE --port 0 --device 0 --type hdd --medium ${MFSFILE}.vdi"
rc_halt "VBoxManage modifyvm $VM --ioapic on --boot1 disk --memory 2048 --vram 12"
rc_halt "VBoxManage modifyvm $VM --nic1 bridged"
rc_halt "VBoxManage modifyvm $VM --bridgeadapter1 ${iface}"
rc_halt "VBoxManage modifyvm $VM --macaddress1 auto"
rc_halt "VBoxManage modifyvm $VM --nictype1 82540EM"
rc_halt "VBoxManage modifyvm $VM --pae off"
rc_halt "VBoxManage modifyvm $VM --usb on"

# Setup serial output
rc_halt "VBoxManage modifyvm $VM --uart1 0x3F8 4"
rc_halt "VBoxManage modifyvm $VM --uartmode1 file /tmp/vboxpipe"

# Attach extra disks to the VM for testing
rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk1 --size 20000"
rc_halt "VBoxManage storageattach $VM --storagectl IDE --port 0 --device 1 --type hdd --medium ${MFSFILE}.disk1"
rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk2 --size 20000"
rc_halt "VBoxManage storageattach $VM --storagectl IDE --port 1 --device 1 --type hdd --medium ${MFSFILE}.disk2"

# Get rid of old output file
if [ -e "/tmp/vboxpipe" ] ; then
  rm /tmp/vboxpipe
fi

echo "Running Installed System..."
daemon -p /tmp/vminstall.pid vboxheadless -startvm "$VM" --vrde off

# Give about 5 minutes to boot, should be ready for REST calls now
sleep 300

# Run the REST tests now
cd ${PROGDIR}/scripts

if [ -n "$FREENASLEGACY" ] ; then
  ./9.3-tests.sh >/tmp/fnas-tests.log 2>/tmp/fnas-tests.log
  res=$?
else
  ./10-tests.sh >/tmp/fnas-tests.log 2>/tmp/fnas-tests.log
  res=$?
fi

# Shutdown that VM
VBoxManage controlvm vminstall poweroff >/dev/null 2>/dev/null
sync

# Delete the VM
VBoxManage unregistervm $VM --delete

echo "Output from console during runtime tests:"
echo "-----------------------------------------"
cat /tmp/vboxpipe

echo "Output from REST API calls:"
echo "-----------------------------------------"
cat /tmp/fnas-tests.log

exit $res
