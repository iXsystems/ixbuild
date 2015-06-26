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

check_rest_response()
{
  grep -q "$1" ${RESTYERR}
  if [ $? -ne 0 ] ; then
    cat ${RESTYERR}
    cat ${RESTYOUT}
    exit 1
  fi
}

rc_halt()
{
  echo "Running: $1"
  ${1}
  if [ $? -ne 0 ] ; then
     ${2}
     exit 1
  fi
}

# Check getting disks
echo "Checking for disks / API functionality"
GET /storage/disk/ -v 2>${RESTYERR} >${RESTYOUT}
check_rest_response "200 OK"


# Check creating a zpool
echo "Creating zpool tank"
POST /storage/volume/ '{ "volume_name" : "tank", "layout" : [ { "vdevtype" : "stripe", "disks" : [ "ada1", "ada2" ] } ] }' -v >${RESTYOUT} 2>${RESTYERR}
check_rest_response "201 CREATED"

# Check creating a dataset
echo "Creating dataset tank/share"
POST /storage/volume/1/datasets/ '{ "name": "share" }' -v >${RESTYOUT} 2>${RESTYERR}
check_rest_response "201 CREATED"

# Set the permissions of the dataset
echo "Setting permissions of /mnt/tank"
PUT /storage/permission/ '{ "mp_path": "/mnt/tank", "mp_acl": "unix", "mp_mode": "777", "mp_user": "root", "mp_group": "wheel" }' -v >${RESTYOUT} 2>${RESTYERR}
check_rest_response "201 CREATED"

# Enable NFS server
echo "Creating the NFS server"
PUT /services/nfs/ '{ "nfs_srv_bindip": "'"${ip}"'", "nfs_srv_mountd_port": 618, "nfs_srv_allow_nonroot": false, "nfs_srv_servers": 10, "nfs_srv_udp": false, "nfs_srv_rpcstatd_port": 871, "nfs_srv_rpclockd_port": 32803, "nfs_srv_v4": false, "id": 1 }' -v >${RESTYOUT} 2>${RESTYERR}
check_rest_response "200 OK"

# Check creating a NFS share
echo "Creating a NFS share on /mnt/tank"
POST /sharing/nfs/ '{ "nfs_comment": "My Test Share", "nfs_paths": ["/mnt/tank"], "nfs_security": "sys" }' -v >${RESTYOUT} 2>${RESTYERR}
check_rest_response "201 CREATED"

# Now start the service
echo "Starting NFS service"
PUT /services/services/nfs/ '{ "srv_enable": true }' -v >${RESTYOUT} 2>${RESTYERR}
check_rest_response "200 OK"

# Now check if we can mount NFS / create / rename / copy / delete / umount
echo "Checking NFS mount"
rc_halt "mkdir /tmp/nfs-mnt.$$"
rc_halt "mount_nfs ${ip}:/mnt/tank /tmp/nfs-mnt.$$" "umount /tmp/nfs-mnt.$$ ; rmdir /tmp/nfs-mnt.$$"
rc_halt "touch /tmp/nfs-mnt.$$/testfile" "umount /tmp/nfs-mnt.$$ ; rmdir /tmp/nfs-mnt.$$"
rc_halt "mv /tmp/nfs-mnt.$$/testfile /tmp/nfs-mnt.$$/testfile2"
rc_halt "cp /tmp/nfs-mnt.$$/testfile2 /tmp/nfs-mnt.$$/testfile"
rc_halt "rm /tmp/nfs-mnt.$$/testfile2"
rc_halt "umount /tmp/nfs-mnt.$$"
rc_halt "rmdir /tmp/nfs-mnt.$$"

# Made it to the end, exit with success!
exit 0
