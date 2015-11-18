#!/usr/local/bin/bash
# Author: Kris Moore
# License: BSD
# Location for tests into REST API of FreeNAS 10.x

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# IP of client we are testing
ip="192.168.0.116"

# Source our resty / jsawk functions
# Resty Docs: https://github.com/micha/resty
# jsawk: https://github.com/micha/jsawk
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u root:testing

RESTYOUT=/tmp/resty.out
RESTYERR=/tmp/resty.err
