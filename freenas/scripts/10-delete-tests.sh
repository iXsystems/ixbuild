#!/usr/local/bin/bash
# Author: Kris Moore
# License: BSD
# Location for tests into API of FreeNAS 10.x

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# IP of client we are testing
if [ -n "$1" ] ; then
  ip="$1"
  manualip="YES"
else
  ip="192.168.56.100"
  manualip="NO"
fi

# Set the username / pass of FreeNAS for REST calls
if [ -n "$2" ] ; then
  fuser="$2"
else
  fuser="root"
fi
if [ -n "$3" ] ; then
  fpass="$3"
else
  fpass="testing"
fi

