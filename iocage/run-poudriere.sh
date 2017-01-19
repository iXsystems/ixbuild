#!/bin/sh

PJAILNAME="iocage"
PPORTS="iocports"
ZROOT="/poud"
POUDCONFDIR="${PROGDIR}/poudriere"
PORTS_GIT_URL="https://github.com/freebsd/freebsd-ports.git"
PORTS_GIT_BRANCH="master"
JAILVER="11.0-RELEASE"
PPKGDIR="${ZROOT}/data/packages/${PJAILNAME}-${PPORTS}"

if [ ! -d "$POUDCONFDIR" ] ; then
  mkdir -p ${POUDCONFDIR}
fi

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

cat >${POUDCONFDIR}/poudriere.conf << EOF
ZPOOL=$ZPOOL
ZROOTFS=$ZROOT
FREEBSD_HOST=file://${DISTDIR}
BUILD_AS_NON_ROOT=no
RESOLV_CONF=/etc/resolv.conf
BASEFS=/poud
USE_PORTLINT=no
USE_TMPFS=${TMPWRK}
DISTFILES_CACHE=/usr/ports/distfiles
CHECK_CHANGED_OPTIONS=verbose
CHECK_CHANGED_DEPS=yes
PARALLEL_JOBS=${BUILDERS}
WRKDIR_ARCHIVE_FORMAT=txz
ALLOW_MAKE_JOBS_PACKAGES="pkg ccache py* llvm* libreoffice* apache-openoffice* webkit* firefox* chrom* gcc* qt5-*"
MAX_EXECUTION_TIME=86400
NOHANG_TIME=12600
ATOMIC_PACKAGE_REPOSITORY=no
PKG_REPO_FROM_HOST=yes
BUILDER_HOSTNAME=builds.trueos.org
PRIORITY_BOOST="pypy openoffice* paraview webkit* llvm*"
GIT_URL=${PORTS_GIT_URL}
FREEBSD_HOST=https://download.freebsd.org
USE_COLORS=yes
NOLINUX=yes
EOF

  if [ "$JOBS" = "yes" ] ; then
    echo "ALLOW_MAKE_JOBS=yes" >> ${POUDCONFDIR}/poudriere.conf
  fi
  # Check if we have a ccache dir to be used
  if [ -e "/ccache" ] ; then
    echo "CCACHE_DIR=/ccache" >> ${POUDCONFDIR}/poudriere.conf
  fi

  # Signing script
  if [ -n "$PKGSIGNCMD" ] ; then
    echo "SIGNING_COMMAND=${PKGSIGNCMD}" >> ${POUDCONFDIR}/poudriere.conf
  fi

  # Set any port make options
  if [ ! -d "${POUDCONFDIR}/poudriere.d" ] ; then
    mkdir -p ${POUDCONFDIR}/poudriere.d
  fi
  cp ${PROGDIR}/iocage/port-options.conf ${POUDCONFDIR}/poudriere.d/${PJAILNAME}-make.conf

}

do_portsnap()
{
  mk_poud_config

  # Kill any previous running jail
  poudriere -e ${POUDCONFDIR} jail -k -j ${PJAILNAME} -p ${PPORTS} 2>/dev/null

  echo "Removing old ports dir..."
  poudriere -e ${POUDCONFDIR} ports -p ${PPORTS} -d
  rm -rf /poud/ports/${PPORTS}

  echo "Pulling ports from ${PORTS_GIT_URL} - ${PORTS_GIT_BRANCH}"
  poudriere -e ${POUDCONFDIR} ports -c -p ${PPORTS} -B ${PORTS_GIT_BRANCH} -m git
  if [ $? -ne 0 ] ; then
    exit_err "Failed pulling ports tree"
  fi
}

update_poud_world()
{
  echo "Removing old jail - $PJAILNAME"
  poudriere -e ${POUDCONFDIR} jail -d -j $PJAILNAME
  rm -rf /poud/jails/$PJAILNAME

  echo "Creating new jail: $PJAILNAME - $JAILVER"
  poudriere -e ${POUDCONFDIR} jail -c -j $PJAILNAME -v $JAILVER -m http
  if [ $? -ne 0 ] ; then
    exit_err "Failed creating poudriere jail"
  fi
}

# Kill any previous running jail
poudriere -e ${POUDCONFDIR} jail -k -j ${PJAILNAME} -p ${PPORTS} 2>/dev/null

# Cleanup old packages?
POUDFLAGS=""
if [ "$WIPEPOUDRIERE" = "true" ] ; then
  POUDFLAGS="-c"
fi

# Create the poud config
mk_poud_config

# Extract the world for this poud build
update_poud_world

# Update the ports tree
do_portsnap

# Start the build
poudriere -e ${POUDCONFDIR} bulk ${POUDFLAGS} -j ${PJAILNAME} -p ${PPORTS} -f ${PROGDIR}/iocage/iocage-ports
if [ $? -ne 0 ] ; then
   echo "Failed poudriere build..."
   exit 1
fi

# Build passed, lets rsync it off this node
if [ -z "$SFTPHOST" ] ; then return 0 ; fi

# Now rsync this sucker
echo "Copying packages to staging area... ${PPKGDIR}/ -> ${SFTPFINALDIR}/pkg/iocage"
ssh ${SFTPUSER}@${SFTPHOST} mkdir -p ${SFTPFINALDIR}/pkg/iocage 2>/dev/null >/dev/null
rsync -a --delete -e 'ssh' ${PPKGDIR}/ ${SFTPUSER}@${SFTPHOST}:${SFTPFINALDIR}/pkg/iocage
if [ $? -ne 0 ] ; then exit 1 ; fi
