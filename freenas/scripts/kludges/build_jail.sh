#!/bin/sh
#
# See README for up to date usage examples.
# vim: syntax=sh noexpandtab
#

# KPM - 6-5-2015 - Pulled from poudriere so we can build ports on -CURRENT
# Set specified version into login.conf
update_version_env() {
        local release="$1"
        local login_env osversion
                
        osversion=`awk '/\#define __FreeBSD_version/ { print $3 }' ${NANO_WORLDDIR}/usr/include/sys/param.h`
        login_env=",UNAME_r=${release% *},UNAME_v=FreeBSD ${release},OSVERSION=${osversion}"
        
        sed -i "" -e "s/,UNAME_r.*:/:/ ; s/:\(setenv.*\):/:\1${login_env}:/" ${NANO_WORLDDIR}/etc/login.conf
        cap_mkdb ${NANO_WORLDDIR}/etc/login.conf
}  

umask 022
cd "$(dirname "$0")/.."
TOP="$(pwd)"

. build/nano_env
. build/functions.sh
. build/repos.sh

. build/nanobsd/nanobsd_funcs.sh

setup_and_export_internal_variables

# File descriptor 3 is used for logging output, see pprint
exec 3>&1

NANO_STARTTIME=`date +%s`
pprint 1 "NanoBSD image ${NANO_NAME} build starting"

trap on_exit EXIT

# Number of jobs to pass to make. Only applies to src so far.
MAKE_JOBS=$(( 2 * $(sysctl -n kern.smp.cpus) + 1 ))
if [ ${MAKE_JOBS} -gt 10 ]; then
        MAKE_JOBS=4
fi
export MAKE_JOBS

NANO_PMAKE="${NANO_PMAKE} -j ${MAKE_JOBS}"

mkdir -p ${MAKEOBJDIRPREFIX}
printenv > ${MAKEOBJDIRPREFIX}/_.env
make_conf_build
build_world
build_kernel

# Override NANO_WORLDDIR, so that we create
# the jail for building ports in a different
# place from the directory used for creating
# the final package.
NANO_WORLDDIR=${NANO_OBJ}/_.j
rm -fr ${NANO_WORLDDIR}
mkdir -p ${NANO_OBJ} ${NANO_WORLDDIR}
printenv > ${NANO_OBJ}/_.env
make_conf_install
install_world LOG=_.ij
install_etc LOG=_.etcj
setup_nanobsd_etc
install_kernel LOG=_.ikj

mkdir -p ${NANO_WORLDDIR}/wrkdirs

if [ -e "${NANO_WORLDDIR}/bin/freebsd-version" ] ; then
  nVer=`${NANO_WORLDDIR}/bin/freebsd-version | cut -d '-' -f 1-2`
  update_version_env "$nVer"
else
  update_version_env "10.3-RELEASE"
fi
