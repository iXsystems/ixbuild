#!/usr/bin/env sh
# Author: Joe Maloney
# License: BSD
# Location for tests into REST API of FreeNAS 9.10

# Where is the ixbuild program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source our Testing functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh

# Installl modules
pip install requests

#################################################################
# Run the tests now!
#################################################################

echo "Using API Address: http://${FNASTESTIP}/api/v2.0"

git clone https://www.github.com/freenas/freenas --depth=1 /freenas
cd /freenas/src/middlewared/middlewared/pytest
echo [Target] > target.conf
echo uri = http://${FNASTESTIP} >> target.conf
echo api = /api/v2.0/ >> target.conf
echo username = "root" >> target.conf
echo password = "testing" >> target.conf
sed -i '' "s|'freenas'|'testing'|g" functional/test_0001_authentication.py
py.test -sv functional --junitxml=$RESULTSDIR/results.xml.v2.0
TOTALTESTS="14"
publish_pytest_results "$TOTALCOUNT"

exit 0
