#!/bin/sh

# Set the variables
TYPE="${1}"
BUILD="${2}"
BRANCH="${3}"

# Change directory
mypath=`realpath $0`
cd `dirname $mypath`

# Source our functions
. build.conf
. functions.sh
######################################################

# Check for the WORKSPACE tag
for var in $@
do
 echo $var | grep -q "WORKSPACE="
 if [ $? -eq 0 ] ; then
   export WORKSPACE=`echo $var | cut -d '=' -f 2`
 fi
done

case $TYPE in
  world) jenkins_world ;;
   jail) jenkins_jail ;;
    pkg) jenkins_pkg ;; 
    iso) jenkins_iso ;;
     vm) jenkins_vm ;;
freenas) jenkins_freenas ;;
freenas-tests) jenkins_freenas_tests ;;
ports-tests) jenkins_ports_tests ;;
      *) echo "Invalid Type: $1" 
         exit 1
         ;;
esac
