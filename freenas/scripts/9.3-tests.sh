#!/usr/local/bin/bash
# Author: Kris Moore
# License: BSD
# Location for tests into REST API of FreeNAS 9.3
# Resty Docs: https://github.com/micha/resty
# jsawk: https://github.com/micha/jsawk

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# IP of client we are testing
if [ -n "$1" ] ; then
  ip="$1"
else
  ip="192.168.0.15"
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

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

# Log files
RESTYOUT=/tmp/resty.out
RESTYERR=/tmp/resty.err

#################################################################
# Run the tests now!
#################################################################

# Check getting disks
echo "Checking for disks / API functionality"
GET /storage/disk/ -v 2>${RESTYERR} >${RESTYOUT}
grep -q "200 OK" ${RESTYERR}
if [ $? -ne 0 ] ; then
  cat ${RESTYERR}
  cat ${RESTYOUT}
  exit 1
fi


# Check creating a zpool
echo "Creating zpool tank"
POST /storage/volume/ '{ "volume_name" : "tank", "layout" : [ { "vdevtype" : "stripe", "disks" : [ "ada1", "ada2" ] } ] }' -v >${RESTYOUT} 2>${RESTYERR}
grep -q "201 CREATED" ${RESTYERR}
if [ $? -ne 0 ] ; then
  cat ${RESTYERR}
  cat ${RESTYOUT}
  exit 1
fi


# Check creating a dataset
echo "Creating dataset tank/share"
POST /storage/volume/1/datasets/ '{ "name": "share" }' -v >${RESTYOUT} 2>${RESTYERR}
grep -q "201 CREATED" ${RESTYERR}
if [ $? -ne 0 ] ; then
  cat ${RESTYERR}
  cat ${RESTYOUT}
  exit 1
fi


# Check creating a NFS share
echo "Creating a NFS share on /mnt/tank"
POST /sharing/nfs/ '{ "nfs_comment": "My Test Share", "nfs_paths": ["/mnt/tank"], "nfs_security": "sys" }' -v >${RESTYOUT} 2>${RESTYERR}
grep -q "201 CREATED" ${RESTYERR}
if [ $? -ne 0 ] ; then
  cat ${RESTYERR}
  cat ${RESTYOUT}
  exit 1
fi


# Made it to the end, exit with success!
exit 0
