#!/bin/sh
# Author: Kris Moore
# License: BSD
# Location for tests into REST API of FreeNAS 9.3

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# IP of client we are testing
ip="192.168.0.15"

# Source our resty / jsawk functions
# Resty Docs: https://github.com/micha/resty
# jsawk: https://github.com/micha/jsawk
. ${PROGDIR}/../utils/resty
