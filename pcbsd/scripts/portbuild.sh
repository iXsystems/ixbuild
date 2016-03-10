#!/bin/sh
# Meta pkg building startup script
#############################################

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/pcbsd.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
sh ${PROGDIR}/scripts/checkprogs.sh
cStat=$?
if [ $cStat -ne 0 ] ; then exit $cStat; fi

merge_pcbsd_src_ports()
{
   local mcwd=`pwd`
   local gitdir="$1"
   local portsdir="$2"
   distCache="/usr/ports/distfiles"

   rc_halt "cd ${gitdir}" >/dev/null 2>/dev/null
     
   # Now use the git script to create source ports
   rc_halt "./mkports.sh ${portsdir} ${distCache}"

   # Jump back to where we belong
   rc_halt "cd $mcwd" >/dev/null 2>/dev/null
}

mk_metapkg_bulkfile()
{
   local bulkList=$1
   rm $bulkList >/dev/null 2>/dev/null

   rc_halt "cp ${PCONFDIR}/essential-packages-nonrel $bulkList"
}

mk_poud_config()
{

# Get the memory in MB on system
MEM=$(sysctl -n hw.physmem)
MEM=$(expr $MEM / 1024)
MEM=$(expr $MEM / 1024)

CPUS=$(sysctl -n kern.smp.cpus)
if [ $CPUS -gt 12 ] ; then
  BUILDERS="12"
  JOBS="YES"
else
  BUILDERS="$CPUS"
  JOBS="NO"
fi

# Determine TMPFS usage based upon Memory to CPUs ratio
MEMPERBUILDER=$(expr $MEM / $CPUS)
if [ $MEMPERBUILDER -gt 4000 ]; then
  TMPWRK="all"
elif [ $MEMPERBUILDER -gt 2000 ] ; then
  TMPWRK="wrkdirs"
else
  TMPWRK="no"
fi

# Allow these defaults to be overridden
BCONF="/usr/local/etc/poudriere-builders.conf"
if [ -e "$BCONF" ] ; then
  grep -q "^BUILDERS=" ${BCONF}
  if [ $? -eq 0 ] ; then
    BUILDERS=$(grep "^BUILDERS=" ${BCONF} | cut -d '=' -f 2)
  fi
  grep -q "^JOBS=" ${BCONF}
  if [ $? -eq 0 ] ; then
    JOBS=$(grep "^JOBS=" ${BCONF} | cut -d '=' -f 2)
  fi
  grep -q "^TMPFSWORK=" ${BCONF}
  if [ $? -eq 0 ] ; then
    TMPWRK=$(grep "^TMPFSWORK=" ${BCONF} | cut -d '=' -f 2)
  fi
fi

cat >/usr/local/etc/poudriere.conf << EOF
NO_ZFS=YES
FREEBSD_HOST=file://${DISTDIR}
RESOLV_CONF=/etc/resolv.conf
BASEFS=/poud
USE_PORTLINT=no
USE_TMPFS=${TMPWRK}
DISTFILES_CACHE=/usr/ports/distfiles
CHECK_CHANGED_OPTIONS=verbose
CHECK_CHANGED_DEPS=yes
PARALLEL_JOBS=${BUILDERS}
WRKDIR_ARCHIVE_FORMAT=txz
ALLOW_MAKE_JOBS=${JOBS}
ALLOW_MAKE_JOBS_PACKAGES="pkg ccache py*"
MAX_EXECUTION_TIME=86400
NOHANG_TIME=7200
ATOMIC_PACKAGE_REPOSITORY=no
BUILDER_HOSTNAME=builds.pcbsd.org
PRIORITY_BOOST="pypy openoffice*"
GIT_URL=${PORTS_GIT_URL}
USE_COLORS=no
EOF

  # Signing script
  if [ -n "$PKGSIGNCMD" ] ; then
    echo "SIGNING_COMMAND=${PKGSIGNCMD}" >> /usr/local/etc/poudriere.conf
  fi

}

do_portsnap()
{
  mk_poud_config

  echo "Removing old ports dir..."
  poudriere ports -p ${PPORTS} -d

  echo "Pulling ports from ${GIT_URL} - ${PORTS_GIT_BRANCH}"
  poudriere ports -c -p ${PPORTS} -B ${PORTS_GIT_BRANCH} -m git
  if [ $? -ne 0 ] ; then
    exit_err "Failed pulling ports tree"
  fi
}

do_pcbsd_portmerge()
{
   # Copy our PCBSD port files
   merge_pcbsd_src_ports "${PCBSDSRC}" "/poud/ports/${PPORTS}"
}

do_pbi-index()
{
   if [ -z "$PBI_REPO_KEY" ] ; then return ; fi

   # See if we can create the PBI index files for this repo
   if [ ! -d "${PCBSDSRC}/pbi-modules" ] ; then
      echo "No pbi-modules in this GIT branch"
      return 1
   fi

   echo "Building new PBI-INDEX"

   # Lets update the PBI-INDEX
   create_pkg_conf
   REPOS_DIR="${PROGDIR}/tmp/repo" ; export REPOS_DIR
   PKG_DBDIR="${PROGDIR}/tmp/repodb" ; export PKG_DBDIR
   if [ -d "$PKG_DBDIR" ] ; then rm -rf ${PKG_DBDIR}; fi
   mkdir -p ${PKG_DBDIR}
   ABIVER=`echo $TARGETREL | cut -d '-' -f 1 | cut -d '.' -f 1`
   PBI_PKGCFLAG="-o ABI=freebsd:${ABIVER}:x86:64" ; export PBI_PKGCFLAG

   rc_halt "cd ${PCBSDSRC}/pbi-modules" >/dev/null 2>/dev/null
   rc_halt "pbi_makeindex ${PBI_REPO_KEY}"
   rc_nohalt "rm PBI-INDEX" >/dev/null 2>/dev/null
   rc_halt "mv PBI-INDEX.txz* ${PPKGDIR}/" >/dev/null 2>/dev/null
   return 0
}

if [ -z "$1" ] ; then
   target="all"
else
   target="$1"
fi

cd ${PROGDIR}

if [ -d "${PCBSDSRC}" ]; then
  rm -rf ${PCBSDSRC}
fi
mkdir -p ${PCBSDSRC}
rc_halt "git clone --depth=1 -b ${GITPCBSDBRANCH} ${GITPCBSDURL} ${PCBSDSRC}"

rc_halt "cd ${PCONFDIR}/" >/dev/null 2>/dev/null
cp ${PCONFDIR}/port-make.conf /usr/local/etc/poudriere.d/${JAILVER}-make.conf

if [ "$target" = "all" ] ; then

  # Remove old PBI-INDEX.txz files
  rm ${PPKGDIR}/PBI-INDEX.txz* 2>/dev/null

  # Create the poud config
  mk_poud_config

  # Extract the world for this poud build
  update_poud_world

  # Build entire ports tree
  poudriere bulk -a -j ${JAILVER} -p ${PPORTS}
  if [ $? -ne 0 ] ; then
     echo "Failed poudriere build..."
  fi

  # Make sure the essentials built, exit now if not
  echo "Checking essential packages..."
  check_essential_pkgs "NO"
  if [ $? -ne 0 ] ; then
     exit 1
  fi

  # Update the PBI index file
  do_pbi-index

  # Unset cleanup var
  pCleanup=""
  export pCleanup

  exit 0
elif [ "$1" = "portsnap" ] ; then
   do_portsnap
   do_pcbsd_portmerge
   exit 0
elif [ "$1" = "portmerge" ] ; then
   do_pcbsd_portmerge
   exit 0
elif [ "$1" = "pbi-index" ] ; then
   do_pbi-index
   exit $?
else
   echo "Invalid option!"
   exit 1
fi
