#!/usr/local/bin/bash
# Author: Kris Moore
# License: BSD
# Location for tests into REST API of FreeNAS 9.3
# Resty Docs: https://github.com/micha/resty
# jsawk: https://github.com/micha/jsawk

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Set variable to call jsawk utility
JSAWK="${PROGDIR}/../utils/jsawk -j js24"

# Test Module directory
TDIR="${PROGDIR}/9.3-tests"

# Log files
RESTYOUT=/tmp/resty.out
RESTYERR=/tmp/resty.err

TOTALCOUNT="0"

#################################################################
# Run the tests now!
#################################################################

# Set the default test type
TESTSET="SMOKE"
export TESTSET

echo_ok()
{
  echo -e " - OK"
}

# Check for $1 REST response, error out if not found
check_rest_response()
{
  grep -q "$1" ${RESTYERR}
  if [ $? -ne 0 ] ; then
    cat ${RESTYERR}
    cat ${RESTYOUT}
    exit 1
  fi
}

check_rest_response_continue()
{
  grep -q "$1" ${RESTYERR}
  return $?
}

# $1 = Command to run
# $2 = Command to run if $1 fails
# $3 = Optional timeout
rc_halt()
{
  if [ -z "$3" ] ; then
    ${1} >/tmp/.cmdTest.$$ 2>/.cmdTest.$$
    if [ $? -ne 0 ] ; then
       echo -e " - FAILED"
       eval "${2}"
       echo "Failed running: $1"
       cat /tmp/.cmdTest.$$
       rm /tmp/.cmdTest.$$
       exit 1
    fi
    rm /tmp/.cmdTest.$$
    return 0
  fi


  # Running with timeout
  ( ${1} >/tmp/.cmdTest.$$ 2>/.cmdTest.$$ ; echo $? > /tmp/.rc-result.$$ ) &
  echo "$!" > /tmp/.rc-pid.$$
  timeout=0
  while :
  do
    # See if the process stopped yet
    pgrep -F /tmp/.rc-pid.$$ >/dev/null 2>/dev/null
    if [ $? -ne 0 ] ; then
      # Check if it was 0
      if [ "$(cat /tmp/.rc-result.$$)" = "0" ] ; then
        rm /tmp/.rc-result.$$
        return 0
      fi
      rm /tmp/.rc-result.$$
      break
    fi

    # Check the timeout
    sleep 1
    timeout=$(expr $timeout + 1)
    if [ $timeout -gt $3 ] ; then break; fi
  done

  rm /tmp/.rc-pid.$$ 2>/dev/null
  rm /tmp/.rc-result.$$ 2>/dev/null

  kill -9 $(cat /tmp/.rc-pid.$$)
  rm /tmp/.rc-pid.$$
  echo -e " - FAILED"
  eval "${2}"
  echo "Timeout running: $1"
  cat /tmp/.cmdTest.$$
  rm /tmp/.cmdTest.$$
  exit 1
}

set_test_group_text()
{
  GROUPTEXT="$1"
  TOTALTESTS="$2"
  TCOUNT=0
}

echo_test_title()
{
  TCOUNT=`expr $TCOUNT + 1`
  TOTALCOUNT=`expr $TOTALCOUNT + 1`
  sync
  echo -e "Running $GROUPTEXT ($TCOUNT/$TOTALTESTS) - $1\c"
}

# Set the IP address of REST
set_ip()
{
  set_test_group_text "Networking Configuration" "4"

  echo_test_title "Setting IP address: ${ip} on em0"
  if [ "$manualip" = "NO" ] ; then
    POST /network/interface/ '{ "int_ipv4address": "'"${ip}"'", "int_name": "internal", "int_v4netmaskbit": "24", "int_interface": "em0" }' -v >${RESTYOUT} 2>${RESTYERR}
    check_rest_response "201 CREATED"
  fi
  echo_ok

  echo_test_title "Setting DHCP on em1"
  POST /network/interface/ '{ "int_dhcp": true, "int_name": "ext", "int_interface": "em1" }' -v >${RESTYOUT} 2>${RESTYERR}
  check_rest_response "201 CREATED"
  echo_ok

  echo_test_title "Rebooting VM"
  POST /system/reboot/ '' -v >${RESTYOUT} 2>${RESTYERR}
  check_rest_response "202 ACCEPTED"
  echo_ok

  echo_test_title "Waiting for reboot"
  sleep 20
  wait_for_avail
  echo_ok
}

wait_for_avail()
{
  count=0
  while :
  do
    GET /storage/disk/ -v 2>${RESTYERR} >${RESTYOUT}
    check_rest_response_continue "200 OK"
    if [ $? -eq 0 ] ; then break; fi
    echo -e ".\c"
    sleep 60
    if [ $count -gt 10 ] ; then
       echo "FreeNAS API failed to respond!"
       exit 1
    fi
    count=`expr $count + 1`
  done
}

run_module() {
  unset REQUIRES

  # Source the module now
  cd ${TDIR}
  . ./${1}
  if [ $? -ne 0 ] ; then
    echo "Failed sourcing ${1}"
    exit 1
  fi

  # Make sure any required module have been run first
  local modreq="$REQUIRES"
  if [ -n "$modreq" ] ; then
    for i in $modreq
    do
      # Check if this module has already been run
      echo $RUNMODULES | grep -q ":::${i}:::"
      if [ $? -eq 0 ] ; then continue; fi

      # Need to run another module first
      echo "***** Running module dependancy: $i *****"
      run_module "$i" "quiet"
    done
  fi

  # Run the target module
  if [ -z "$2" ] ; then
    echo "***** Running module: $1 *****"
  fi
  eval "${1}_init"
  if [ $? -ne 0 ] ; then
    echo "Failed on test module: $1"
    exit 1
  fi

  # Save that this test was already run
  RUNMODULES="${RUNMODULES}:::${1}:::"
}

# Read through the test modules and start running them
read_module_dir() {
  cd ${TDIR}
  if [ $? -ne 0 ] ; then
    echo "Missing test module dir"
    exit 1
  fi

  RUNMODULES=""

  for module in `ls`
  do
    # Skip the README, other files should be valid though
    if [ "$module" = "README" ] ; then continue ; fi

    # Check if this module has already been run
    echo $RUNMODULES | grep -q ":::${module}:::"
    if [ $? -eq 0 ] ; then continue ; fi

    run_module "$module"
  done
}

# Set the defaults for connecting to the VM
ip="192.168.56.100"
manualip="NO"
fuser="root"
fpass="testing"


while [ $# -gt 0 ] ; do
  # Parse the CLI args
  key=`echo $1 | cut -d '=' -f 1`
  val=`echo $1 | cut -d '=' -f 2`

  case "$key" in
    testset|TESTSET) case "$val" in
			SMOKE|smoke) export TESTSET="SMOKE" ;;
	  	  COMPLETE|complete) export TESTSET="COMPLETE" ;;
		BENCHMARK|benchmark) export TESTSET="BENCHMARK" ;;
			*) ;;
                     esac
                     ;; 
     module|MODULE) runmod="$val $runmod" ;;
     ip|IP) ip="$val" ; manualip="YES" ;;
     user|USER) fuser="$val" ;;
     pass|PASS) fpass="$val" ;;
    *) ;;
  esac
  shift
done

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

# When running via Jenkins / ATF mode, it may take a variable
# time to boot the system and be ready for REST calls. We run
# an initial test to determine when the interface is up
echo -e "Testing access to REST API\c"
wait_for_avail
echo_ok

# Reset the IP address via REST
set_ip

if [ -n "$runmod" ] ; then
  for mod in $runmod
  do
    # Run a specific module
    run_module "$mod"
  done
else
  # Now start going through our test modules
  read_module_dir
fi

# Made it to the end, exit with success!
echo "SUCCESS - $TOTALCOUNT tests run - REST API testing complete!"
exit 0
