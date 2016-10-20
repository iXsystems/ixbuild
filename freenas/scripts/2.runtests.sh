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

# Run the REST tests now
cd ${PROGDIR}/scripts

if [ -n "$FREENASLEGACY" ] ; then
  break
else
  if [ ! -d "/freenas-build" ] ; then
    git clone https://www.github.com/freenas/freenas-build.git --depth=1 /freenas-build
  fi
  cd /freenas-build && git pull
  make checkout profile=freenas-10
  # Display output to stdout
  OUTFILE="/tmp/fnas-build.out.$$" 
  touch ${OUTFILE}
  (tail -f ${OUTFILE} 2>/dev/null) &
  TPID=$!
  kldstat | grep -q "vmm"
  if [ $? -ne 0 ] ; then
    kldload vmm
  fi
  kldstat | grep -q "if_tap"
  if [ $? -ne 0 ] ; then
    kldload if_tap
    sysctl net.link.tap.up_on_open=1
  fi
  cd /freenas-10 && make tests profile=freenas-10 BUILD_LOGLEVEL=DEBUG >${OUTFILE} 2>${OUTFILE}
  if [ $? -ne 0 ] ; then
    kill -9 $TPID 2>/dev/null
    echo_fail "Failed running make checkout"
    exit 1
  fi
  kill -9 $TPID 2>/dev/null
  echo_ok
  exit 0
fi

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

# Set the default VMBACKEND
if [ -z "$VMBACKEND" ] ; then
  VMBACKEND="vbox"
fi

# Determine which VM backend to start
case ${VMBACKEND} in
     bhyve) start_bhyve ;;
     esxi) cp ${PROGDIR}/tmp/$BUILDTAG.iso /autoinstalls/$BUILDTAG.iso
	   daemon -p /tmp/vmcu.pid cu -l /dev/ttyu0 -s 115200 > /tmp/console.log 2>/dev/null &
	   sleep 30
           clean_xml_results
           exit 0
	   ;;
	*) start_vbox ;;
esac

# Cleanup old test results before running tests
clean_xml_results

# Run tests now
run_tests

# Determine which VM backend to stop
case ${VMBACKEND} in
    bhyve) stop_bhyve ;;
    esxi ) stop_esxi ;;
       * ) stop_vbox ;;
esac
