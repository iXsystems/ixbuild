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
ifconfig tap0 >/dev/null 2>/dev/null
if [ $? -ne 0 ] ; then
  iface=`netstat -f inet -nrW | grep '^default' | awk '{ print $6 }'`
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
  if [ \$count -gt 360 ] ; then break; fi
  echo -e \".\c\"

  sleep 10
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

echo "Bhyve installation successful!"
sleep 1

# Exit for now, can't do live run until grub-bhyve is updated
#exit 0

echo "Starting testing now!"

# Start grub-bhyve

kldunload vmm
kldload vboxdrv
kldload vboxnetflt
kldload vboxnetadp

# Create the VDI
rm ${MFSFILE}.vdi 2>/dev/null
rc_halt "VBoxManage convertfromraw --format VDI ${MFSFILE} ${MFSFILE}.vdi"

# Create the OVA file now
VM="vminstall"
# Remove any crashed / old VM
VBoxManage unregistervm $VM --delete >/dev/null 2>/dev/null
          
rc_halt "VBoxManage createvm --name $VM --ostype FreeBSD_64 --register"
rc_halt "VBoxManage storagectl $VM --name IDE --add ide --controller PIIX4"
rc_halt "VBoxManage storageattach $VM --storagectl IDE --port 0 --device 0 --type hdd --medium ${MFSFILE}.vdi"
rc_halt "VBoxManage modifyvm $VM --ioapic on --boot1 disk --memory 2048 --vram 12"
rc_halt "VBoxManage modifyvm $VM --nic1 nat"
rc_halt "VBoxManage modifyvm $VM --macaddress1 auto"
rc_halt "VBoxManage modifyvm $VM --nictype1 82540EM"
rc_halt "VBoxManage modifyvm $VM --pae off"
rc_halt "VBoxManage modifyvm $VM --usb on"
rc_halt "VBoxManage modifyvm $VM --uart1 0x3F8 4"
rm /tmp/vboxpipe 2>/dev/null
rc_halt "VBoxManage modifyvm $VM --uartmode1 file /tmp/vboxpipe"

echo "Running VBoxHeadless"
vboxheadless -startvm "$VM" --vrde off

rc_halt "VBoxManage unregistervm $VM --delete"

echo ""
