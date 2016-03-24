start_xml_results() {
  cat >/tmp/results.xml.$$ << EOF
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite tests="TOTALTESTS">
EOF
}

# 1 = true/false
# 2 = error message
# 3 = stdout
# 4 = stderr
add_xml_result() {
  if [ "$1" = "true" ] ; then
    cat >>/tmp/results.xml.$$ << EOF
    <testcase classname="$CLASSNAME" name="$TESTNAME"/>
EOF
  else
    # Failed!
    cat >>/tmp/results.xml.$$ << EOF
    <testcase classname="$CLASSNAME" name="$TESTNAME">
        <failure type="failure">$2</failure>
EOF
    # Optional stdout / stderr logs
if [ -n "$3" ] ; then
  echo "         <system-out>`cat $3`</system-out>" >> /tmp/results.xml.$$
fi
if [ -n "$4" ] ; then
  echo "         <system-err>`cat $4`</system-err>" >> /tmp/results.xml.$$
fi

    # Close the error tag
    cat >>/tmp/results.xml.$$ << EOF
    </testcase>
EOF
  fi
}

finish_xml_results() {
  cat >>/tmp/results.xml.$$ << EOF
</testsuite>
EOF

  # Set the total number of tests run
  sed -i '' "s|TOTALTESTS|$1|g" /tmp/results.xml.$$

  # Move results to pre-defined location
  if [ -n "$BUILD_TAG" ] ; then
    if [ ! -d "/ixbuild/results" ] ; then
      mkdir -p /ixbuild/results
    fi
    mv /tmp/results.xml.$$ /ixbuild/results/${BUILD_TAG}.xml
  else
    mv /tmp/results.xml.$$ /tmp/test-results.xml
  fi
}


# $1 = Command to run
# $2 = Command to run if $1 fails
# $3 = Optional timeout
rc_test()
{
  if [ -z "$3" ] ; then
    ${1} >/tmp/.cmdTest.$$ 2>/.cmdTest.$$
    if [ $? -ne 0 ] ; then
       echo -e " - FAILED"
       eval "${2}"
       echo "Failed running: $1"
       cat /tmp/.cmdTest.$$
       rm /tmp/.cmdTest.$$
       return 1
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

  kill -9 $(cat /tmp/.rc-pid.$$)
  rm /tmp/.rc-pid.$$
  rm /tmp/.rc-result.$$ 2>/dev/null
  echo_failed
  add_xml_result "false" "Timeout running command: $1" "/tmp/.cmdTest.$$" "$RESTYERR"
  eval "${2}"
  echo "Timeout running: $1"
  cat /tmp/.cmdTest.$$
  rm /tmp/.cmdTest.$$
  return 1
}

echo_ok()
{
  echo -e " - OK"
}

echo_fail()
{
  echo -e " - FAILED"
}

# Check for $1 REST response, error out if not found
check_rest_response()
{ 
  grep -q "$1" ${RESTYERR}
  if [ $? -ne 0 ] ; then
    cat ${RESTYERR}
    cat ${RESTYOUT}
    add_xml_result  "false" "Invalid REST response" "$RESTYOUT" "$RESTYERR"
    echo_fail
    return 1
  fi

  add_xml_result "true" "Valid REST response" "$RESTYOUT" "$RESTYERR"
  echo_ok
  return 0
}

check_rest_response_continue()
{
  grep -q "$1" ${RESTYERR}
  return $?
}

set_test_group_text()
{
  GROUPTEXT="$1"
  CLASSNAME="$1"
  TOTALTESTS="$2"
  TCOUNT=0
}

echo_test_title()
{
  TESTNAME="$1"
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
  else
    echo_ok
  fi

  echo_test_title "Setting DHCP on em1"
  POST /network/interface/ '{ "int_dhcp": true, "int_name": "ext", "int_interface": "em1" }' -v >${RESTYOUT} 2>${RESTYERR}
  check_rest_response "201 CREATED"

  echo_test_title "Rebooting VM"
  POST /system/reboot/ '' -v >${RESTYOUT} 2>${RESTYERR}
  check_rest_response "202 ACCEPTED"

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
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi

  # Make sure any required module have been run first
  local modreq="$REQUIRES"
  local nofails="true"
  if [ -n "$modreq" ] ; then
    for i in $modreq
    do
      # Check if this module has already been run
      echo $RUNMODULES | grep -q ":::${i}:::"
      if [ $? -eq 0 ] ; then continue; fi

      echo $FAILEDMODULES | grep -q ":::${i}:::"
      if [ $? -eq 0 ] ; then
	CLASSNAME="$1"
	TESTNAME="all"
        TOTALCOUNT=`expr $TOTALCOUNT + 1`
        echo "***** Skipping test module: $1 ($i failed) *****"
        add_xml_result "false" "Skipped due to $i requirement failing"
        FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
        return 1
      fi

      # Need to run another module first
      echo "***** Running module dependancy: $i *****"
      run_module "$i" "quiet"
      if [ $? -ne 0 ] ; then
        nofails="false"
      fi
    done
  fi

  if [ "$nofails" = "false" ] ; then
    CLASSNAME="$1"
    TESTNAME="all"
    TOTALCOUNT=`expr $TOTALCOUNT + 1`
    echo "***** Skipping test module: $1 (Dep failed) *****"
    add_xml_result "false" "Skipped test module: $i requirement failing"
    return 1
  fi

  # Run the target module
  if [ -z "$2" ] ; then
    echo "***** Running module: $1 *****"
  fi
  eval "${1}_init"
  if [ $? -ne 0 ] ; then
    echo "Failed on test module: $1"
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi

  # Save that this test was already run
  RUNMODULES="${RUNMODULES}:::${1}:::"
  return 0
}

# Read through the test modules and start running them
read_module_dir() {
  cd ${TDIR}
  if [ $? -ne 0 ] ; then
    echo "Missing test module dir"
    exit 1
  fi

  RUNMODULES=""
  ANYFAILS="false"

  for module in `ls`
  do
    # Skip the README, other files should be valid though
    if [ "$module" = "README" ] ; then continue ; fi

    # Check if this module has already been run
    echo $RUNMODULES | grep -q ":::${module}:::"
    if [ $? -eq 0 ] ; then continue ; fi

    # Check if this module has already been skipped
    echo $FAILEDMODULES | grep -q ":::${module}:::"
    if [ $? -eq 0 ] ; then continue ; fi

    run_module "$module"
    if [ $? -ne 0 ] ; then
      ANYFAILS="true"
    fi
  done

  if [ "$ANYFAILS" = "true" ] ; then return 1; fi
  return 0 
}
