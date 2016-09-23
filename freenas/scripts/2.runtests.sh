#!/usr/local/bin/bash

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh
. ${PROGDIR}/scripts/functions-vm.sh

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

# Prepare to build autoinstall ISO
if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
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

# Set the name for VM
VM="$BUILDTAG"
export VM

# Determine which VM backend to start
if [ -n "$USE_BHYVE" ] ; then
  start_bhyve
elif [ -n "$USE_EXT_VM"] ; then
  echo "auto-install ISO has been created"
  clean_xml_results
  exit 0
else
  start_vbox
fi

# Cleanup old test results before running tests
clean_xml_results

# Run the REST tests now
echo "Starting testing now!"
cd ${PROGDIR}/scripts
if [ -n "$FREENASLEGACY" ] ; then
  ./9.10-create-tests.sh ip=$FNASTESTIP 2>&1 | tee >/tmp/$VM-tests-create.log 
  ./9.10-update-tests.sh ip=$FNASTESTIP 2>&1 | tee >/tmp/$VM-tests-update.log
  ./9.10-delete-tests.sh ip=$FNASTESTIP 2>&1 | tee >/tmp/$VM-tests-delete.log
  res=$?
else
  ./10-create-tests.sh ip=$FNASTESTIP 2>&1 | tee >/tmp/$VM-tests-create.log
  ./10-update-tests.sh ip=$FNASTESTIP 2>&1 | tee >/tmp/$VM-tests-update.log
  ./10-delete-tests.sh ip=$FNASTESTIP 2>&1 | tee >/tmp/$VM-tests-delete.log
  res=$?
fi

# Determine which VM backend to stop
if [ -n "$USE_BHYVE" ] ; then
  stop_bhyve
else
  stop_vbox
fi
