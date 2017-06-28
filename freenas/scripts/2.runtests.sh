#!/usr/bin/env bash

# Where is the pcbsd-build program installed
PROGDIR="`realpath $0 | xargs dirname | xargs dirname`"
export PROGDIR

# ISO absolute file path
ISOFILE="${1}"
# Local location of FreeNAS build
[ -n "$BUILDTAG" ] && export FNASBDIR="/$BUILDTAG" || export FNASBDIR="/freenas"

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh
. ${PROGDIR}/scripts/functions-vm.sh

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

# Make sure we have all the required packages installed
if uname -a | grep -q "FreeBSD" ; then
  ${PROGDIR}/scripts/checkprogs.sh
fi

# Run the REST tests now
cd ${PROGDIR}/scripts
get_bedir

# If no ISO file path given as argument, figure out the ISO name
if [ -z "${ISOFILE}" ] ; then
  echo "Finding ISO file..."
  if [ -d "${FNASBDIR}/objs" ] ; then
    ISOFILE=`find ${FNASBDIR}/objs | grep '\.iso$' | head -n 1`
  elif [ -d "${BEDIR}/release" ] ; then
    ISOFILE=`find ${BEDIR}/release | grep '\.iso$' | head -n 1`
  else
    ISOFILE=`find ${PROGDIR}/../objs | grep '\.iso$' | head -n 1`
  fi
fi

# Validate that an ISO selection was determined and exists
if [ -z "$ISOFILE" ] ; then
  exit_err "Failed locating ISO file, did 'make release' work?"
elif [ ! -f "${ISOFILE}" ] ; then
  exit_err "Failed locating ISO file - \"${ISOFILE}\""
fi

# Is this TrueNAS or FreeNAS?
echo $ISOFILE | grep -q "TrueNAS" && export FLAVOR="TRUENAS" || export FLAVOR="FREENAS"
echo "Using ISO: $ISOFILE"

# Prepare to build autoinstall ISO
[ ! -d "${PROGDIR}/tmp" ] && mkdir ${PROGDIR}/tmp

# Create the automatic ISO installer if not using bhyve as VM backend,
# bhyve is able to interact with the installer to set the root password.
if [ "${VMBACKEND}" != "bhyve" ] ; then
  cd ${PROGDIR}/tmp
  ${PROGDIR}/scripts/create-auto-install.sh ${ISOFILE} || exit_err "Failed creating auto-install ISO!"
fi

# Set the name for VM
VM="$BUILDTAG"
export VM

# Set the default VMBACKEND
if [ -z "$VMBACKEND" ] ; then
  VMBACKEND="vbox"
fi

# Copy ISO to autoinstalls if using jailed test executor
[ -f "/tmp/$BUILDTAG" ] && cp /$BUILDTAG.iso /autoinstalls

# Determine which VM backend to start
case ${VMBACKEND} in
  bhyve)
    # Grab assigned FNASTESTIP from bhyve installation/boot-up output
    export FNASTESTIP=$(start_bhyve $ISOFILE | tee /dev/tty | grep '^FNASTESTIP=' | sed 's|^FNASTESTIP=||g')
    export BRIDGEIP=${FNASTESTIP}
    ;;
  esxi)
    cp ${PROGDIR}/tmp/$BUILDTAG.iso /autoinstalls/$BUILDTAG.iso 2>/dev/null &
    daemon -p /tmp/vmcu.pid cu -l /dev/ttyu0 -s 115200 > /tmp/console.log 2>/dev/null &
    sleep 30
    clean_xml_results
    echo "Shutting down any previous instances of ${VM}.."
    stop_vmware
    sleep 60
    echo "Reverting to snapshot..."
    revert_vmware
    sleep 30
    install_vmware
    sleep 60
    boot_vmware
    ;;
  *)
    start_vbox
    ;;
esac

# Cleanup old test results before running tests
clean_xml_results

# If running in a jailed executor, remove build dir and exit
[ -f "/tmp/${BUILDTAG}" ] && (rm -rf /tmp/build; exit 0)

# Run tests now
run_tests
exit $?
