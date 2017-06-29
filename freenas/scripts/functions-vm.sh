#!/usr/bin/env sh

# Where is the ixbuild program installed
PROGDIR="`realpath $0 | xargs dirname | xargs dirname`"
export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh

start_bhyve()
{
  if [ ! -f "/usr/local/share/uefi-firmware/BHYVE_UEFI.fd" ] ; then
    echo "File not found: /usr/local/share/uefi-firmware/BHYVE_UEFI.fd"
    echo "Install the \"uefi-edk2-bhyve\" port. Exiting."
    exit 1
  fi

  # Allow the $IXBUILD_BRIDGE, $IXBUILD_IFACE, $IXBUILD_TAP to be overridden
  [ -z "${IXBUILD_BRIDGE}" ] && export IXBUILD_BRIDGE="ixbuildbridge0"
  [ -z "${IXBUILD_IFACE}" ] && export IXBUILD_IFACE="`netstat -f inet -nrW | grep '^default' | awk '{ print $6 }'`"
  [ -z "${IXBUILD_TAP}" ] && export IXBUILD_TAP="tap"

  local ISOFILE=$1
  local VM_OUTPUT="/tmp/${BUILDTAG}-bhyve.out"
  local VOLUME="tank"
  local DATADISKOS="${BUILDTAG}-os"
  local DATADISK1="${BUILDTAG}-data1"
  local DATADISK2="${BUILDTAG}-data2"
  local IXBUILD_DNSMASQ=$(test -n "${IXBUILD_DNSMASQ}" && echo "${IXBUILD_DNSMASQ}" || which dnsmasq)
  local BOOT_PIDFILE="/tmp/.cu-${BUILDTAG}-boot.pid"
  local TAP_LOCKFILE="/tmp/.tap-${BUILDTAG}.lck"

  # Verify kernel modules are loaded if this is a BSD system
  if which kldstat >/dev/null 2>/dev/null ; then
    kldstat | grep -q if_tap || kldload if_tap
    kldstat | grep -q if_bridge || kldload if_bridge
    kldstat | grep -q vmm || kldload vmm
    kldstat | grep -q nmdm || kldload nmdm
  fi

  # Shutdown VM, stop output, and cleanup
  bhyvectl --destroy --vm=$BUILDTAG &>/dev/null &
  ifconfig ${IXBUILD_BRIDGE} destroy &>/dev/null
  ifconfig ${IXBUILD_TAP} destroy &>/dev/null
  rm "${VM_OUTPUT}" &>/dev/null
  [ -f "${BOOT_PIDFILE}" ] && cat "${BOOT_PIDFILE}" | xargs kill &>/dev/null
  [ -f "${TAP_LOCKFILE}" ] && cat "${TAP_LOCKFILE}" | xargs -I {} ifconfig {} destroy && rm "${TAP_LOCKFILE}"

  # Destroy zvols from previous runs
  local zfs_list=$(zfs list | awk 'NR>1 {print $1}')
  echo ${zfs_list} | grep -q "${VOLUME}/${DATADISKOS}" && zfs destroy ${VOLUME}/${DATADISKOS}
  echo ${zfs_list} | grep -q "${VOLUME}/${DATADISK1}" && zfs destroy ${VOLUME}/${DATADISK1}
  echo ${zfs_list} | grep -q "${VOLUME}/${DATADISK2}" && zfs destroy ${VOLUME}/${DATADISK2}

  echo "Setting up bhyve network interfaces..."

  # Auto-up tap devices and allow forwarding
  sysctl net.link.tap.up_on_open=1 &>/dev/null
  sysctl net.inet.ip.forwarding=1 &>/dev/null

  # Lets check status of ${IXBUILD_TAP} device
  if ! ifconfig ${IXBUILD_TAP} >/dev/null 2>/dev/null ; then
    IXBUILD_TAP=$(ifconfig ${IXBUILD_TAP} create)
    # Save the tap interface name, generated or specified. Used for clean-up.
    echo ${IXBUILD_TAP} > ${TAP_LOCKFILE}
  fi

  # Check the status of our network bridge
  if ! ifconfig ${IXBUILD_BRIDGE} >/dev/null 2>/dev/null ; then
    bridge=$(ifconfig bridge create)
    ifconfig ${bridge} name ${IXBUILD_BRIDGE} >/dev/null
  fi

  # Ensure $IXBUILD_IFACE is a member of our bridge.
  if ! ifconfig ${IXBUILD_BRIDGE} | grep -q "member: ${IXBUILD_IFACE}" ; then
    ifconfig ${IXBUILD_BRIDGE} addm ${IXBUILD_IFACE}
  fi

  # Ensure $IXBUILD_TAP is a member of our bridge.
  if ! ifconfig ${IXBUILD_BRIDGE} | grep -q "member: ${IXBUILD_TAP}" ; then
    ifconfig ${IXBUILD_BRIDGE} addm ${IXBUILD_TAP}
  fi

  # Finally, have our bridge pickup an IP Address
  ifconfig ${IXBUILD_BRIDGE} up && dhclient ${IXBUILD_BRIDGE}

  ###############################################
  # Now lets spin-up bhyve and do an installation
  ###############################################

  echo "Performing bhyve installation..."

  # Determine which nullmodem slot to use for the installation
  local com_idx=0
  until ! ls /dev/nmdm* 2>/dev/null | grep -q "/dev/nmdm${com_idx}A" ; do com_idx=$(expr $com_idx + 1); done
  local COM_BROADCAST="/dev/nmdm${com_idx}A"
  local COM_LISTEN="/dev/nmdm${com_idx}B"

  # Create our OS disk and data disks
  # To stop the host from sniffing partitions, which could cause the install
  # to fail, we set the zfs option volmode=dev on the OS parition
  local os_size=20
  local disk_size=50
  local freespace=$(df -h | awk '$6 == "/" {print $4}' | sed 's|G$||')
  # Decrease os and data disk sizes if less than 120G is avail on the root mountpoint
  if [ -n "$freespace" -a $freespace -le 120 ] ; then os_size=10; disk_size=5; fi

  zfs create -V ${os_size}G -o volmode=dev ${VOLUME}/${DATADISKOS}
  zfs create -V ${disk_size}G ${VOLUME}/${DATADISK1}
  zfs create -V ${disk_size}G ${VOLUME}/${DATADISK2}

  # Install from our ISO
  ( bhyve -w -A -H -P -c 1 -m 2G \
    -s 0:0,hostbridge \
    -s 1:0,lpc \
    -s 2:0,virtio-net,${IXBUILD_TAP} \
    -s 4:0,ahci-cd,${ISOFILE} \
    -s 5:0,ahci-hd,/dev/zvol/${VOLUME}/${DATADISKOS} \
    -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
    -l com1,${COM_BROADCAST} \
    $BUILDTAG ) &

  # Run our expect/tcl script to automate the installation dialog
  ${PROGDIR}/scripts/bhyve-installer.exp "${COM_LISTEN}" "${VM_OUTPUT}"
  echo -e \\033c # Reset/clear to get native term dimensions
  echo "Installation completed."

  # Shutdown VM, stop output
  sleep 30
  bhyvectl --destroy --vm=$BUILDTAG &>/dev/null &

  # Determine which nullmodem slot to use for boot-up
  local com_idx=0
  until ! ls /dev/nmdm* 2>/dev/null | grep -q "/dev/nmdm${com_idx}A" ; do com_idx=$(expr $com_idx + 1); done
  local COM_BROADCAST="/dev/nmdm${com_idx}A"
  local COM_LISTEN="/dev/nmdm${com_idx}B"

  # Fixes: ERROR: "vm_open: Invalid argument"
  sleep 10

  ( bhyve -w -A -H -P -c 1 -m 2G \
    -s 0:0,hostbridge \
    -s 1:0,lpc \
    -s 2:0,virtio-net,${IXBUILD_TAP} \
    -s 5:0,ahci-hd,/dev/zvol/${VOLUME}/${DATADISKOS} \
    -s 6:0,ahci-hd,/dev/zvol/${VOLUME}/${DATADISK1} \
    -s 7:0,ahci-hd,/dev/zvol/${VOLUME}/${DATADISK2} \
    -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
    -l com1,${COM_BROADCAST} \
    $BUILDTAG ) &

  ${PROGDIR}/scripts/bhyve-bootup.exp "${COM_LISTEN}" "${VM_OUTPUT}"

  local EXIT_STATUS=1
  if grep -q "Starting nginx." ${VM_OUTPUT} || grep -q "Plugin loaded: SSHPlugin" ${VM_OUTPUT} ; then
    local FNASTESTIP="$(awk '$0 ~ /^vtnet0:\ flags=/ {++n;next}; n == 2 && $1 == "inet" {print $2;exit}' ${VM_OUTPUT})"
    if [ -n "${FNASTESTIP}" ] ; then
      echo "FNASTESTIP=${FNASTESTIP}"
      EXIT_STATUS=0
    else
      echo "ERROR: No ip address assigned to VM. FNASTESTIP not set."
    fi
  fi

  return $EXIT_STATUS
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

  # Verify kernel modules are loaded
  kldstat | grep -q vboxdrv || kldload vboxdrv >/dev/null 2>/dev/null
  # Onestart will run even if service is started
  kldstat | grep -q vboxnet || service vboxnet onestart

  # Now lets spin-up vbox and do an installation
  ######################################################
  while :
  do
    runningvm=$(VBoxManage list runningvms | grep ${VM})
    OS=`echo $runningvm | cut -d \" -f 2`
    if [ "${VM}" == "${OS}" ]; then
      echo "A previous instance of ${VM} is still running!"
      echo "Shutting down ${VM}"
      VBoxManage controlvm $BUILDTAG poweroff >/dev/null 2>/dev/null
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
  VBoxManage unregistervm $BUILDTAG >/dev/null 2>/dev/null
  rm -rf "/root/VirtualBox VMs/$BUILDTAG" >/dev/null 2>/dev/null

  # Copy ISO over to /root in case we need to grab it from jenkins node later
  cp ${PROGDIR}/tmp/$BUILDTAG.iso /root/$BUILDTAG.iso

  # Remove from the vbox registry
  VBoxManage closemedium dvd ${PROGDIR}/tmp/$BUILDTAG.iso >/dev/null 2>/dev/null

  # Create the VM in virtualbox
  rc_halt "VBoxManage createvm --name $BUILDTAG --ostype FreeBSD_64 --register"
  rc_halt "VBoxManage storagectl $BUILDTAG --name SATA --add sata --controller IntelAhci"
  rc_halt "VBoxManage storageattach $BUILDTAG --storagectl SATA --port 0 --device 0 --type hdd --medium ${MFSFILE}.vdi"
  rc_halt "VBoxManage storageattach $BUILDTAG --storagectl SATA --port 1 --device 0 --type dvddrive --medium ${PROGDIR}/tmp/$BUILDTAG.iso"
  rc_halt "VBoxManage modifyvm $BUILDTAG --cpus 1 --ioapic on --boot1 disk --memory 4096 --vram 12"
  rc_nohalt "VBoxManage hostonlyif remove vboxnet0"
  rc_halt "VBoxManage hostonlyif create"
  rc_halt "VBoxManage modifyvm $BUILDTAG --nic1 hostonly"
  rc_halt "VBoxManage modifyvm $BUILDTAG --hostonlyadapter1 vboxnet0"
  rc_halt "VBoxManage modifyvm $BUILDTAG --macaddress1 auto"
  rc_halt "VBoxManage modifyvm $BUILDTAG --nicpromisc1 allow-all"
  if [ -n "$BRIDGEIP" ] ; then
    # Switch to bridged mode
    DEFAULTNIC=`netstat -nr | grep "^default" | awk '{print $4}'`
    rc_halt "VBoxManage modifyvm $BUILDTAG --nictype1 82540EM"
    rc_halt "VBoxManage modifyvm $BUILDTAG --nic2 bridged"
    rc_halt "VBoxManage modifyvm $BUILDTAG --bridgeadapter2 ${DEFAULTNIC}"
    rc_halt "VBoxManage modifyvm $BUILDTAG --nicpromisc2 allow-all"
  else
    # Fallback to NAT
    rc_halt "VBoxManage modifyvm $BUILDTAG --nictype1 82540EM"
    rc_halt "VBoxManage modifyvm $BUILDTAG --nic2 nat"
  fi
  rc_halt "VBoxManage modifyvm $BUILDTAG --macaddress2 auto"
  rc_halt "VBoxManage modifyvm $BUILDTAG --nictype2 82540EM"
  rc_halt "VBoxManage modifyvm $BUILDTAG --pae off"
  rc_halt "VBoxManage modifyvm $BUILDTAG --usb on"

  # Setup serial output
  rc_halt "VBoxManage modifyvm $BUILDTAG --uart1 0x3F8 4"
  rc_halt "VBoxManage modifyvm $BUILDTAG --uartmode1 file /tmp/$BUILDTAG.vboxpipe"

  # Just in case the install hung, we don't need to be waiting for over an hour
  echo "Performing $BUILDTAG installation..."
  count=0

  # Unload VB
  VBoxManage controlvm $BUILDTAG poweroff >/dev/null 2>/dev/null

  # Start the VM
  daemon -p "/tmp/${VM}.pid" vboxheadless -startvm "$BUILDTAG" --vrde off

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
      cat /tmp/$BUILDTAG.vboxpipe
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
    echo -n "."

    sleep 30
  done

  # Make sure VM is shutdown
  VBoxManage controlvm $BUILDTAG poweroff >/dev/null 2>/dev/null

  # Remove from the vbox registry
  # Give extra time to ensure VM is shutdown to avoid CAM errors
  sleep 30
  VBoxManage closemedium dvd ${PROGDIR}/tmp/$BUILDTAG.iso >/dev/null 2>/dev/null

  # Set the DVD drive to empty
  rc_halt "VBoxManage storageattach $BUILDTAG --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive"

  # Display output of VM serial mode
  echo "OUTPUT FROM INSTALLATION CONSOLE..."
  echo "---------------------------------------------"
  cat /tmp/$BUILDTAG.vboxpipe
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

  echo "$BUILDTAG installation successful!"
  sleep 30

  runningvm=$(VBoxManage list runningvms | grep ${VM})
  OS=`echo $runningvm | cut -d \" -f 2`
  if [ "${VM}" == "${OS}" ]; then
    echo "Warning ${VM} has failed to shut down!"
  else
    echo "$BUILDTAG has been successfully shut down"
  fi

  echo "Attaching extra disks for testing"

  # Attach extra disks to the VM for testing
  rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk1 --size 20000"
  rc_halt "VBoxManage storageattach $BUILDTAG --storagectl SATA --port 1 --device 0 --type hdd --medium ${MFSFILE}.disk1"
  rc_halt "VBoxManage createhd --filename ${MFSFILE}.disk2 --size 20000"
  rc_halt "VBoxManage storageattach $BUILDTAG --storagectl SATA --port 2 --device 0 --type hdd --medium ${MFSFILE}.disk2"

  sleep 30

  # Get rid of old output file
  if [ -e "/tmp/$BUILDTAG.vboxpipe" ] ; then
    rm /tmp/$BUILDTAG.vboxpipe
  fi

  sleep 30

  echo "Running Installed System..."
  daemon -p /tmp/$BUILDTAG.pid vboxheadless -startvm "$BUILDTAG" --vrde off

  # Give a minute to boot, should be ready for REST calls now
  echo "Waiting up to 8 minutes for $BUILDTAG to boot with hostpipe output"
  sleep 480

  return 0
}

stop_vbox()
{
  # Shutdown that VM
  VBoxManage controlvm $BUILDTAG poweroff >/dev/null 2>/dev/null
  sync

  # Delete the VM
  VBoxManage unregistervm $BUILDTAG --delete

  echo ""
  echo "Output from console during runtime tests:"
  echo "-----------------------------------------"
  cat /tmp/$BUILDTAG.vboxpipe
  echo ""
  echo "Output from REST API calls:"
  echo "-----------------------------------------"
  cat /tmp/$BUILDTAG-tests-create.log
  cat /tmp/$BUILDTAG-tests-update.log
  cat /tmp/$BUILDTAG-tests-delete.log

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
  tail -f /autoinstalls/$BUILDTAG.out 2>/dev/null &

  timeout_seconds=1800
  timeout_when=$(( $(date +%s) + $timeout_seconds ))

  # Wait for installation to finish
  while ! grep -q "Installation finished. No error reported." /autoinstalls/$BUILDTAG.out
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
  tail -f /autoinstalls/$BUILDTAG.out 2>/dev/null &

  timeout_seconds=1800
  timeout_when=$(( $(date +%s) + $timeout_seconds ))

  # Wait for bootup to finish
  # Wait for bootup to finish
  while ! ((grep -q "Starting nginx." /autoinstalls/$BUILDTAG.out) || (grep -q "Plugin loaded: SSHPlugin" /autoinstalls/$BUILDTAG.out))
  do
    if [ $(date +%s) -gt $timeout_when ]; then
      echo "Timeout reached before bootup finished."
      break
    fi
    sleep 2
  done

  return $CMD_RESULTS
}

resume_vmware()
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

  echo "Resuming ${VM}..."

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
