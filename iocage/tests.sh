#!/bin/sh
# Author: Joe Maloney
# License: BSD

# Where is the ixbuild program installed
PROGDIR="$(dirname "$(realpath "$(dirname "$0")")")"; export PROGDIR

# Reuse FreeNAS test functions
${PROGDIR}/../freenas/scripts/functions.sh
${PROGDIR}/../freenas/scripts/functions-tests.sh

# Set which python, pip versions to use
PYTHON="/usr/bin/env python3.6"
PIP="/usr/bin/env pip3.6"

#################################################################
# Run the tests now!
#################################################################

cd $WORKSPACE
git checkout master
make install
service iocage onestart
$PYTHON -m pytest --zpool zroot --junitxml=$RESULTSDIR/results.xml 
TOTALTESTS="1"
publish_pytest_results "$TOTALCOUNT"

exit 0
