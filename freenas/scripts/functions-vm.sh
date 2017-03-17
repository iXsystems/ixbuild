#!/usr/bin/env sh

# Where is the ixbuild program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh

start_bhyve()
{
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

cp ${PROGDIR}/tmp/$BUILDTAG.iso /root/

# Just in case the install hung, we don't need to be waiting for over an hour
echo "Performing bhyve installation..."
count=0

kldstat | grep -q "vmm"
if [ $? -ne 0 ] ; then
  kldload vmm
fi

# Start grub-bhyve
bhyvectl --destroy --vm=$VM >/dev/null 2>/dev/null
echo "(hd0) ${MFSFILE}
(cd0) ${PROGDIR}/tmp/$BUILDTAG.iso" > ${PROGDIR}/tmp/device.map

# We run the bhyve commands in a seperate screen session, so that they can run
# in jenkins / save output
echo "#!/bin/sh
count=0

grub-bhyve -m ${PROGDIR}/tmp/device.map -r cd0 -M 2048M $VM

daemon -p /tmp/$VM.pid bhyve -AI -H -P -s 0:0,hostbridge -s 1:0,lpc -s 2:0,virtio-net,tap0 -s 3:0,virtio-blk,${MFSFILE} -s 4:0,ahci-cd,${PROGDIR}/tmp/$BUILDTAG.iso -l com1,stdio -c 4 -m 2048M $VM

# Wait for initial bhyve startup
while :
do
  if [ ! -e "/tmp/$VM.pid" ] ; then break; fi

  pgrep -qF /tmp/$VM.pid
  if [ \$? -ne 0 ] ; then
        break;
  fi

  count=\`expr \$count + 1\`
  if [ \$count -gt 360 ] ; then break; fi
  echo -e \".\c\"

  sleep 10
done

# Cleanup the old VM
bhyvectl --destroy --vm=$VM
"> ${PROGDIR}/tmp/screen-$VM.sh
chmod 755 ${PROGDIR}/tmp/screen-$VM.sh

echo "Running bhyve in screen session, will display when finished..."
screen -Dm -L -S vmscreen ${PROGDIR}/tmp/screen-$VM.sh

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

echo "Starting Bhyve testing now!"

# Start grub-bhyve
echo "(hd0) ${MFSFILE}" > ${PROGDIR}/tmp/device.map

# We run the bhyve commands in a seperate screen session, so that they can run
# in jenkins / save output
echo "#!/bin/sh
count=0

grub-bhyve -m ${PROGDIR}/tmp/device.map -M 2048M $VM

daemon -p /tmp/$VM.pid bhyve -AI -H -P -s 0:0,hostbridge -s 1:0,lpc -s 2:0,virtio-net,tap0 -s 3:0,virtio-blk,${MFSFILE} -l com1,stdio -c 4 -m 2048M $VM

# Wait for initial bhyve startup
while :
do
  if [ ! -e "/tmp/$VM.pid" ] ; then break; fi

  pgrep -qF /tmp/$VM.pid
  if [ \$? -ne 0 ] ; then
        break;
  fi

  count=\`expr \$count + 1\`
  if [ \$count -gt 65 ] ; then break; fi
  echo -e \".\c\"

  sleep 10
done
}

stop_bhyve()
{
# Cleanup the old VM
bhyvectl --destroy --vm=$VM
"> ${PROGDIR}/tmp/screen-$VM.sh
chmod 755 ${PROGDIR}/tmp/screen-$VM.sh

echo "Running bhyve tests in screen session, will display when finished..."
screen -Dm -L -S vmscreen ${PROGDIR}/tmp/screen-$VM.sh

# Display output of screen command
cat flush
echo "" 
}

start_vbox() 
{
# We now run virtualbox headless
kldunload vmm 2>/dev/null >/dev/null
# Remove bridge0/tap0 so vbox bridge mode works
ifconfig bridge0 destroy >/dev/null 2>/dev/null
ifconfig tap0 destroy >/dev/null 2>/dev/null

# Get the default interface
iface=`netstat -f inet -nrW | grep '^default' | awk '{ print $6 }'`

# This will try to load the module even if it is already loaded
# Load up VBOX
# kldstat | grep -q vboxdrv
# if [ $? -eq 0 ] ; then
#  kldload vboxdrv >/dev/null 2>/dev/null
# fi
# kldstat | grep -q vboxnet
# if [ $? -eq 0 ] ; then
# Onestart will run if even if service is started
#  service vboxnet onestart
# fi

# Now lets spin-up vbox and do an installation
######################################################
while :
do
runningvm=$(VBoxManage list runningvms | grep ${VM})
OS=`echo $runningvm | cut -d \" -f 2`
if [ "${VM}" == "${OS}" ]; then
  echo "A previous instance of ${VM} is still running!"
  echo "Shutting down ${VM}"
  VBoxManage controlvm $VM poweroff >/dev/null 2>/dev/null
  sleep 10
else
  echo "Checking for previous running instances of ${VM}... none found"
  break
fi
done

# Restarting vboxnet before tests can actually break networking
# Try restarting virtualbox networking to ensure network should work
# service vboxnet restart
# sleep 60

MFSFILE="${PROGDIR}/tmp/freenas-disk0.img"
echo "Creating $MFSFILE"
rc_halt "VBoxManage createhd --filename ${MFSFILE}.vdi --size 20000"

# Remove any crashed / old VM
VBoxManage unregistervm $VM >/dev/null 2>/dev/null
rm -rf "/root/VirtualBox VMs/$VM" >/dev/null 2>/dev/null

# Copy ISO over to /root in case we need to grab it from jenkins node later
  cp ${PROGDIR}/tmp/$BUILDTAG.iso /root/$BUILDTAG.iso

# Remove from the vbox registry
VBoxManage closemedium dvd ${PROGDIR}/tmp/$BUILDTAG.iso >/dev/null 2>/dev/null

# Create the VM in virtualbox
rc_halt "VBoxManage createvm --name $VM --ostype FreeBSD_64 --register"
rc_halt "VBoxManage storagectl $VM --name SATA --add sata --controller IntelAhci"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 0 --device 0 --type hdd --medium ${MFSFILE}.vdi"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type dvddrive --medium ${PROGDIR}/tmp/$BUILDTAG.iso"
rc_halt "VBoxManage modifyvm $VM --cpus 1 --ioapic on --boot1 disk --memory 4096 --vram 12"
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
rc_halt "VBoxManage modifyvm $VM --uartmode1 file /tmp/$VM.vboxpipe"

# Just in case the install hung, we don't need to be waiting for over an hour
echo "Performing $VM installation..."
count=0

# Unload VB
VBoxManage controlvm $VM poweroff >/dev/null 2>/dev/null

# Start the VM
daemon -p "/tmp/${VM}.pid" vboxheadless -startvm "$VM" --vrde off

sleep 5
if [ ! -e "/tmp/${VM}.pid" ] ; then
  echo "WARNING: Missing /tmp/${VM}.pid"
fi

# Wait for initial virtualbox startup
count=0
while :
do
  
  # Check if the install failed
  grep -q "installation on ada0 has failed" "/tmp/${VM}.vboxpipe"
  if [ $? -eq 0 ] ; then
    cat /tmp/$VM.vboxpipe
    echo_fail
    break
  fi

  if [ ! -e "/tmp/${VM}.pid" ] ; then break; fi

  pgrep -qF /tmp/${VM}.pid
  if [ $? -ne 0 ] ; then
    echo "pgrep -qF /tmp/${VM}.pid detects install finished"
    break;
  fi

  count=`expr $count + 1`
  if [ $count -gt 20 ] ; then break; fi
  echo -e ".\c"

  sleep 30
done

# Make sure VM is shutdown
VBoxManage controlvm $VM poweroff >/dev/null 2>/dev/null

# Remove from the vbox registry
# Give extra time to ensure VM is shutdown to avoid CAM errors
sleep 30
VBoxManage closemedium dvd ${PROGDIR}/tmp/$BUILDTAG.iso >/dev/null 2>/dev/null

# Set the DVD drive to empty
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive"

# Display output of VM serial mode
echo "OUTPUT FROM INSTALLATION CONSOLE..."
echo "---------------------------------------------"
cat /tmp/$VM.vboxpipe
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

echo "$VM installation successful!"
sleep 30

runningvm=$(VBoxManage list runningvms | grep ${VM})
OS=`echo $runningvm | cut -d \" -f 2`
if [ "${VM}" == "${OS}" ]; then
  echo "Warning ${VM} has failed to shut down!"
else
  echo "$VM has been successfully shut down"
fi

echo "Attaching extra disks for testing"

# Attach extra disks to the VM for testing
rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk1 --size 20000"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type hdd --medium ${MFSFILE}.disk1"
rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk2 --size 20000"
rc_halt "VBoxManage storageattach $VM --storagectl SATA --port 2 --device 0 --type hdd --medium ${MFSFILE}.disk2"

sleep 30

# Get rid of old output file
if [ -e "/tmp/$VM.vboxpipe" ] ; then
  rm /tmp/$VM.vboxpipe
fi

sleep 30

echo "Running Installed System..."
daemon -p /tmp/$VM.pid vboxheadless -startvm "$VM" --vrde off

# Give a minute to boot, should be ready for REST calls now
echo "Waiting up to 8 minutes for $VM to boot with hostpipe output"
sleep 480
}

stop_vbox()
{
# Shutdown that VM
VBoxManage controlvm $VM poweroff >/dev/null 2>/dev/null
sync

# Delete the VM
VBoxManage unregistervm $VM --delete

echo ""
echo "Output from console during runtime tests:"
echo "-----------------------------------------"
cat /tmp/$VM.vboxpipe
echo ""
echo "Output from REST API calls:"
echo "-----------------------------------------"
cat /tmp/$VM-tests-create.log
cat /tmp/$VM-tests-update.log
cat /tmp/$VM-tests-delete.log

exit $res
}

revert_vmware()
{
  if [ -z  "$VI_SERVER" -o -z "$VI_USERNAME" -o -z "$VI_PASSWORD" -o -z "$VI_CFG" ]; then 
    echo -n "VMWare start|stop|revert commands require the VI_SERVER, "
    echo "VI_USERNAME and VI_PASSWORD config variables to be set in the build.conf"
    return 1
  fi

  pkg info "net/vmware-vsphere-cli" >/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
    echo "Please install net/vmware-vsphere-cli"
    return 1
  fi

  #vmware-cmd revertsnapshot
  vmware-cmd -U $VI_USERNAME -P $VI_PASSWORD -H $VI_SERVER "${VI_CFG}" revertsnapshot
  return $?
}

# $1 = Optional timeout (seconds)
install_vmware()
{
  if [ -z  "$VI_SERVER" -o -z "$VI_USERNAME" -o -z "$VI_PASSWORD" -o -z "$VI_CFG" ]; then 
    echo -n "VMWare start|stop|revert commands require the VI_SERVER, "
    echo "VI_USERNAME and VI_PASSWORD config variables to be set in the build.conf"
    return 1
  fi

  pkg info "net/vmware-vsphere-cli" >/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
    echo "Please install net/vmware-vsphere-cli"
    return 1
  fi

  #vmware-cmd start
  vmware-cmd -U $VI_USERNAME -P $VI_PASSWORD -H $VI_SERVER "${VI_CFG}" start
  CMD_RESULTS=$?

  echo "Installing ${VM}..."

  #Get console output for install
  tpid=$!
  tail -f /tmp/console.log 2>/dev/null &

  timeout_seconds=1800
  timeout_when=$(( $(date +%s) + $timeout_seconds ))

  # Wait for installation to finish
  while ! grep -q "Installation finished. No error reported." /tmp/console.log
  do
    if [ $(date +%s) -gt $timeout_when ]; then
      echo "Timeout reached before installation finished. Exiting."
        break
    fi  
    sleep 2
  done

  #Stop console output
  kill -9 $tpid

  return $CMD_RESULTS
}

# $1 = Optional timeout (seconds)
boot_vmware()
{
  if [ -z  "$VI_SERVER" -o -z "$VI_USERNAME" -o -z "$VI_PASSWORD" -o -z "$VI_CFG" ]; then 
    echo -n "VMWare start|stop|revert commands require the VI_SERVER, "
    echo "VI_USERNAME and VI_PASSWORD config variables to be set in the build.conf"
    return 1
  fi

  pkg info "net/vmware-vsphere-cli" >/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
    echo "Please install net/vmware-vsphere-cli"
    return 1
  fi

  #vmware-cmd start
  vmware-cmd -U $VI_USERNAME -P $VI_PASSWORD -H $VI_SERVER "${VI_CFG}" start
  CMD_RESULTS=$?

  echo "Booting ${VM}..."

  #Get console output for bootup
  tpid=$!
  tail -f /tmp/console.log 2>/dev/null &

  timeout_seconds=1800
  timeout_when=$(( $(date +%s) + $timeout_seconds ))

  # Wait for bootup to finish
  # Wait for bootup to finish
  while ! ((grep -q "Starting nginx." /tmp/console.log) || (grep -q "Plugin loaded: SSHPlugin" /tmp/console.log))
  do
    if [ $(date +%s) -gt $timeout_when ]; then
      echo "Timeout reached before bootup finished."
      break
    fi
    sleep 2
  done

  return $CMD_RESULTS
}

stop_vmware()
{
  if [ -z  "$VI_SERVER" -o -z "$VI_USERNAME" -o -z "$VI_PASSWORD" -o -z "$VI_CFG" ]; then 
    echo -n "VMWare start|stop|revert commands require the VI_SERVER, "
    echo "VI_USERNAME and VI_PASSWORD config variables to be set in the build.conf"
    return 1
  fi

  pkg info "net/vmware-vsphere-cli" >/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
    echo "Please install net/vmware-vsphere-cli"
    return 1
  fi

  #vmware-cmd stop
  vmware-cmd -U $VI_USERNAME -P $VI_PASSWORD -H $VI_SERVER "${VI_CFG}" stop hard
  return $?
}
