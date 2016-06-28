#!/bin/sh
# Meta pkg building startup script
#############################################

# Where is the build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/trueos.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
sh ${PROGDIR}/scripts/checkprogs.sh
cStat=$?
if [ $cStat -ne 0 ] ; then exit $cStat; fi

merge_trueos_src_ports()
{
   local mcwd=`pwd`
   local gitdir="$1"
   local portsdir="$2"
   distCache="/usr/ports/distfiles"

   rc_halt "cd ${gitdir}" >/dev/null 2>/dev/null
     
   # Jump back to where we belong
   rc_halt "cd $mcwd" >/dev/null 2>/dev/null

   # If on 10.x we can stop now
   if [ -n "$TRUEOSLEGACY" ] ; then return 0 ; fi

   # Now add all the additional ports not apart of the main trueos repo
   TREPOS="trueos/trueos-libsh \
	  trueos/lpreserver \
	  trueos/pc-updatemanager \
	  trueos/pc-sysinstall \
	  trueos/trueos-libqt5 \
	  trueos/trueos-utils \
	  trueos/trueos-utils-qt5 \
	  trueos/trueos-server \
	  trueos/trueos-desktop"

   for repo in $TREPOS
   do
     dname=$(basename $repo)
     rc_halt "git clone --depth=1 https://github.com/${repo}.git"
     rc_halt "cd $dname"
     rc_halt "./mkport.sh ${portsdir} ${distCache}"
     rc_halt "cd $mcwd" >/dev/null 2>/dev/null
   done
}

mk_metapkg_bulkfile()
{
   local bulkList=$1
   rm $bulkList >/dev/null 2>/dev/null

   rc_halt "cp ${PCONFDIR}/desktop/essential-packages-iso $bulkList"
}

mk_poud_config()
{

# Get the memory in MB on system
MEM=$(sysctl -n hw.physmem)
MEM=$(expr $MEM / 1024)
MEM=$(expr $MEM / 1024)

CPUS=$(sysctl -n kern.smp.cpus)
if [ $CPUS -gt 16 ] ; then
  BUILDERS="16"
  JOBS="YES"
else
  BUILDERS="$CPUS"
  JOBS="NO"
fi

# Determine TMPFS usage based upon Memory to CPUs ratio
MEMPERBUILDER=$(expr $MEM / $CPUS)
if [ $MEMPERBUILDER -gt 1500 ]; then
  TMPWRK="all"
elif [ $MEMPERBUILDER -gt 750 ] ; then
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

# Figure out ZFS settings
ZPOOL=$(mount | grep 'on / ' | cut -d '/' -f 1)
ZROOT="/poud"

cat >/usr/local/etc/poudriere.conf << EOF
ZPOOL=$ZPOOL
ZROOTFS=$ZROOT
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
ALLOW_MAKE_JOBS_PACKAGES="pkg ccache py* llvm* libreoffice* apache-openoffice* webkit* firefox* chrom* gcc*"
MAX_EXECUTION_TIME=86400
NOHANG_TIME=12600
ATOMIC_PACKAGE_REPOSITORY=no
PKG_REPO_FROM_HOST=yes
BUILDER_HOSTNAME=builds.trueos.org
PRIORITY_BOOST="pypy openoffice*"
GIT_URL=${PORTS_GIT_URL}
USE_COLORS=yes
EOF

  if [ "$JOBS" = "yes" ] ; then
    echo "ALLOW_MAKE_JOBS=yes" >> /usr/local/etc/poudriere.conf
  fi
  # Check if we have a ccache dir to be used
  if [ -e "/ccache" ] ; then
    echo "CCACHE_DIR=/ccache" >> /usr/local/etc/poudriere.conf
  fi

  # Signing script
  if [ -n "$PKGSIGNCMD" ] ; then
    echo "SIGNING_COMMAND=${PKGSIGNCMD}" >> /usr/local/etc/poudriere.conf
  fi

}

do_portsnap()
{
  mk_poud_config

  # Kill any previous running jail
  poudriere jail -k -j ${PJAILNAME} -p ${PPORTS} 2>/dev/null

  echo "Removing old ports dir..."
  poudriere ports -p ${PPORTS} -d
  rm -rf /poud/ports/${PPORTS}

  echo "Pulling ports from ${PORTS_GIT_URL} - ${PORTS_GIT_BRANCH}"
  poudriere ports -c -p ${PPORTS} -B ${PORTS_GIT_BRANCH} -m git
  if [ $? -ne 0 ] ; then
    exit_err "Failed pulling ports tree"
  fi
}

do_trueos_portmerge()
{
   # Copy our TRUEOS port files
   merge_trueos_src_ports "${TRUEOSSRC}" "/poud/ports/${PPORTS}"
}

do_pbi-index()
{
   if [ -z "$PBI_REPO_KEY" ] ; then return 0; fi

   # See if we can create the PBI index files for this repo
   if [ ! -d "${TRUEOSSRC}/pbi-modules" ] ; then return 0; fi

   echo "Building new PBI-INDEX"

   # Lets update the PBI-INDEX
   create_pkg_conf
   REPOS_DIR="${PROGDIR}/tmp/repo" ; export REPOS_DIR
   PKG_DBDIR="${PROGDIR}/tmp/repodb" ; export PKG_DBDIR
   if [ -d "$PKG_DBDIR" ] ; then rm -rf ${PKG_DBDIR}; fi
   mkdir -p ${PKG_DBDIR}
   ABIVER=`echo $TARGETREL | cut -d '-' -f 1 | cut -d '.' -f 1`
   PBI_PKGCFLAG="-o ABI=freebsd:${ABIVER}:x86:64" ; export PBI_PKGCFLAG

   rc_halt "cd ${TRUEOSSRC}/pbi-modules" >/dev/null 2>/dev/null
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

if [ -d "${TRUEOSSRC}" ]; then
  rm -rf ${TRUEOSSRC}
fi
mkdir -p ${TRUEOSSRC}
echo "git clone --depth=1 -b ${GITTRUEOSBRANCH} ${GITTRUEOSURL} ${TRUEOSSRC}"
rc_halt "git clone --depth=1 -b ${GITTRUEOSBRANCH} ${GITTRUEOSURL} ${TRUEOSSRC}"

rc_halt "cd ${PCONFDIR}/" >/dev/null 2>/dev/null
cp ${PCONFDIR}/port-make.conf /usr/local/etc/poudriere.d/${PJAILNAME}-make.conf

if [ "$target" = "all" ] ; then

  # Kill any previous running jail
  poudriere jail -k -j ${PJAILNAME} -p ${PPORTS} 2>/dev/null

  # Remove old PBI-INDEX.txz files
  rm ${PPKGDIR}/PBI-INDEX.txz* 2>/dev/null

  # Create the poud config
  mk_poud_config

  # Extract the world for this poud build
  update_poud_world

  # Build entire ports tree
  poudriere bulk -a -j ${PJAILNAME} -p ${PPORTS}
  if [ $? -ne 0 ] ; then
     echo "Failed poudriere build..."
  fi

  # Make sure the essentials built, exit now if not
  echo "Checking essential packages for release..."
  check_essential_pkgs "${PCONFDIR}/desktop/essential-packages-release"
  if [ $? -ne 0 ] ; then
     exit 1
  fi

  # Update the PBI index file
  do_pbi-index

  exit 0
elif [ "$target" = "iso" ] ; then

  # Kill any previous running jail
  poudriere jail -k -j ${PJAILNAME} -p ${PPORTS} 2>/dev/null

  # Create the poud config
  mk_poud_config

  # Extract the world for this poud build
  update_poud_world

  # Start the build
  poudriere bulk -j ${PJAILNAME} -p ${PPORTS} -f ${PCONFDIR}/desktop/essential-packages-iso
  if [ $? -ne 0 ] ; then
     echo "Failed poudriere build..."
  fi

  # Make sure the essentials built, exit now if not
  echo "Checking essential packages for ISO creation..."
  check_essential_pkgs "${PCONFDIR}/desktop/essential-packages-iso"
  if [ $? -ne 0 ] ; then
     exit 1
  fi

  exit 0
elif [ "$1" = "portsnap" ] ; then
   do_portsnap
   do_trueos_portmerge
   exit 0
elif [ "$1" = "portmerge" ] ; then
   do_trueos_portmerge
   exit 0
elif [ "$1" = "pbi-index" ] ; then
   do_pbi-index
   exit $?
else
   echo "Invalid option!"
   exit 1
fi
