#!/bin/sh
# Author: Joe Maloney
# License: BSD
# Location for tests into REST API of FreeNAS 9.10

# Source our Testing functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh

#################################################################
# Run the tests now!
#################################################################

echo "Using API Address: ${ip}/v2.0"

cd $FNASSRC/src/middlewared/middlewared/pytest
echo [Target] >> target.conf
echo uri = http://10.20.0.130 > target.conf
echo api = /api/v2.0/ > target.conf
echo username = "root" > target.conf
echo password = "testing" > target.conf
sed -i '' "s|'freenas'|'testing'|g" functional/test_0001_authentication.py
py.test -sv functional --junitxml=$RESULTSDIR/api-v2.0-results.xml

exit 0
